import Foundation
import SwiftUI
import WatchConnectivity
import WatchKit

enum WatchWorkoutTermination: Equatable {
    case save(endDate: Date)
    case discard
}

@MainActor
final class WatchWorkoutStore: NSObject, ObservableObject {
    @Published private(set) var weeklyPlan: [WatchWorkoutPlan] = []
    @Published private(set) var activeWorkout: WatchActiveWorkout?
    @Published private(set) var currentExerciseIndex = 0
    @Published private(set) var currentSetIndex = 0
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var isReachable = false
    @Published private(set) var lastSyncDate: Date?
    @Published private(set) var syncError: String?
    @Published private(set) var healthTermination: WatchWorkoutTermination?
    @Published private(set) var completedPrescriptionIDs: Set<UUID> = []

    private enum StorageKey {
        static let weeklyPlan = "fitnessBuddy.watch.weeklyPlan.v1"
        static let activeWorkout = "fitnessBuddy.watch.activeWorkout.v1"
        static let currentExerciseIndex = "fitnessBuddy.watch.exerciseIndex.v1"
        static let currentSetIndex = "fitnessBuddy.watch.setIndex.v1"
        static let restEndsAt = "fitnessBuddy.watch.restEndsAt.v1"
        static let completedPrescriptionIDs = "fitnessBuddy.watch.completedPrescriptionIDs.v1"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var connectivitySession: WCSession?
    private var restTask: Task<Void, Never>?

    var currentExercise: WatchActiveExercise? {
        guard let activeWorkout,
              activeWorkout.exercises.indices.contains(currentExerciseIndex) else { return nil }
        return activeWorkout.exercises[currentExerciseIndex]
    }

    var currentSet: WatchLoggedSet? {
        guard let currentExercise,
              currentExercise.sets.indices.contains(currentSetIndex) else { return nil }
        return currentExercise.sets[currentSetIndex]
    }

    var progress: Double {
        guard let activeWorkout, activeWorkout.totalSetCount > 0 else { return 0 }
        return Double(activeWorkout.completedSetCount) / Double(activeWorkout.totalSetCount)
    }

    var nextWorkout: WatchWorkoutPlan? {
        let now = Calendar.autoupdatingCurrent.startOfDay(for: Date())
        return weeklyPlan.filter { !isCompleted($0) }.min { lhs, rhs in
            abs(lhs.scheduledDate.timeIntervalSince(now)) < abs(rhs.scheduledDate.timeIntervalSince(now))
        }
    }

    var connectionLabel: String {
        if isReachable { return "IPHONE LIVE" }
        if lastSyncDate != nil { return "PLAN ON WATCH" }
        return "AWAITING IPHONE"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
        restoreState()
        #if DEBUG
        seedAppStoreScreenshotPlanIfNeeded()
        #endif
        activateConnectivity()
        restoreRestTimerIfNeeded()
    }

    deinit {
        restTask?.cancel()
    }

    func start(_ plan: WatchWorkoutPlan) {
        guard activeWorkout == nil, !plan.exercises.isEmpty, !isCompleted(plan) else {
            syncError = isCompleted(plan) ? "WORKOUT ALREADY SAVED" : nil
            return
        }
        healthTermination = nil
        activeWorkout = WatchActiveWorkout(plan: plan)
        currentExerciseIndex = 0
        currentSetIndex = 0
        restEndsAt = nil
        persistActiveState()
        WKInterfaceDevice.current().play(.start)
        sendEvent([
            "type": "watchWorkoutStarted",
            "sessionID": activeWorkout?.sessionID.uuidString ?? "",
            "workoutID": plan.id.uuidString,
            "startedAt": Date(),
        ])
    }

    func select(exerciseIndex: Int, setIndex: Int) {
        guard let activeWorkout,
              activeWorkout.exercises.indices.contains(exerciseIndex),
              activeWorkout.exercises[exerciseIndex].sets.indices.contains(setIndex),
              !activeWorkout.exercises[exerciseIndex].sets[setIndex].isComplete else { return }
        currentExerciseIndex = exerciseIndex
        currentSetIndex = setIndex
        persistActiveState()
        WKInterfaceDevice.current().play(.click)
    }

    func changeWeight(direction: Int) {
        guard let set = currentSet, set.tracksNumericLoad, set.incrementKG > 0 else { return }
        mutateCurrentSet { set in
            let candidate = max(set.weightKG + (Double(direction) * set.incrementKG), 0)
            set.weightKG = (candidate / set.incrementKG).rounded() * set.incrementKG
        }
        WKInterfaceDevice.current().play(direction > 0 ? .directionUp : .directionDown)
    }

    func changeReps(by amount: Int) {
        mutateCurrentSet { set in
            set.reps = min(max(set.reps + amount, 0), 99)
        }
        WKInterfaceDevice.current().play(amount > 0 ? .directionUp : .directionDown)
    }

    func setRIR(_ value: Int) {
        mutateCurrentSet { set in
            set.reportedRIR = min(max(value, 0), 5)
        }
        WKInterfaceDevice.current().play(.click)
    }

    func completeCurrentSet() {
        guard var workout = activeWorkout,
              workout.exercises.indices.contains(currentExerciseIndex),
              workout.exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex),
              !workout.exercises[currentExerciseIndex].sets[currentSetIndex].isComplete,
              workout.exercises[currentExerciseIndex].sets[currentSetIndex].reportedRIR != nil
        else {
            WKInterfaceDevice.current().play(.failure)
            return
        }

        var completedSet = workout.exercises[currentExerciseIndex].sets[currentSetIndex]
        completedSet.isComplete = true
        completedSet.completedAt = Date()
        workout.exercises[currentExerciseIndex].sets[currentSetIndex] = completedSet
        let completedExercise = workout.exercises[currentExerciseIndex]
        activeWorkout = workout
        persistActiveState()

        sendEvent([
            "type": "completedSet",
            "eventID": UUID().uuidString,
            "sessionID": workout.sessionID.uuidString,
            "workoutID": workout.prescriptionID.uuidString,
            "exerciseID": completedExercise.exerciseID,
            "setNumber": completedSet.setNumber,
            "weightKG": completedSet.weightKG,
            "reps": completedSet.reps,
            "reportedRIR": completedSet.reportedRIR ?? completedSet.targetRIR,
            "completedAt": completedSet.completedAt ?? Date(),
            "restSeconds": completedSet.restSeconds,
        ])

        WKInterfaceDevice.current().play(.success)
        if !workout.isComplete {
            beginRest(seconds: completedSet.restSeconds)
            advanceToNextIncomplete()
        } else {
            cancelRest()
            WKInterfaceDevice.current().play(.notification)
        }
    }

    func skipRest() {
        cancelRest()
        WKInterfaceDevice.current().play(.click)
    }

    func finishWorkout() {
        guard let workout = activeWorkout else { return }
        let endDate = Date()
        let completedSetSnapshots: [[String: Any]] = workout.exercises.flatMap { exercise in
            exercise.sets.compactMap { set in
                guard set.isComplete, let reportedRIR = set.reportedRIR else { return nil }
                return [
                    "eventID": "\(workout.sessionID.uuidString)-\(exercise.exerciseID)-\(set.setNumber)",
                    "exerciseID": exercise.exerciseID,
                    "setNumber": set.setNumber,
                    "weightKG": set.weightKG,
                    "reps": set.reps,
                    "reportedRIR": reportedRIR,
                    "completedAt": set.completedAt ?? endDate,
                    "restSeconds": set.restSeconds,
                ]
            }
        }
        sendEvent([
            "type": "watchWorkoutCompleted",
            "sessionID": workout.sessionID.uuidString,
            "workoutID": workout.prescriptionID.uuidString,
            "startedAt": workout.startedAt,
            "endedAt": endDate,
            "completedSets": workout.completedSetCount,
            "totalSets": workout.totalSetCount,
            "completedSetSnapshots": completedSetSnapshots,
        ])
        completedPrescriptionIDs.insert(workout.prescriptionID)
        persistCompletedPrescriptionIDs()
        clearActiveWorkout(termination: .save(endDate: endDate))
        WKInterfaceDevice.current().play(.success)
    }

    func discardWorkout() {
        guard let workout = activeWorkout else { return }
        sendEvent([
            "type": "watchWorkoutDiscarded",
            "sessionID": workout.sessionID.uuidString,
            "workoutID": workout.prescriptionID.uuidString,
            "discardedAt": Date(),
        ])
        clearActiveWorkout(termination: .discard)
        WKInterfaceDevice.current().play(.stop)
    }

    func consumeHealthTermination() {
        healthTermination = nil
    }

    func isCompleted(_ plan: WatchWorkoutPlan) -> Bool {
        completedPrescriptionIDs.contains(plan.id)
    }

    func requestPlanRefresh() {
        sendEvent(["type": "requestWeeklyPlan", "requestedAt": Date()])
        WKInterfaceDevice.current().play(.click)
    }

    private func mutateCurrentSet(_ mutation: (inout WatchLoggedSet) -> Void) {
        guard var workout = activeWorkout,
              workout.exercises.indices.contains(currentExerciseIndex),
              workout.exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex),
              !workout.exercises[currentExerciseIndex].sets[currentSetIndex].isComplete else { return }
        mutation(&workout.exercises[currentExerciseIndex].sets[currentSetIndex])
        activeWorkout = workout
        persistActiveState()
    }

    private func advanceToNextIncomplete() {
        guard let activeWorkout else { return }

        for exerciseIndex in currentExerciseIndex..<activeWorkout.exercises.count {
            let setStart = exerciseIndex == currentExerciseIndex ? currentSetIndex + 1 : 0
            guard setStart < activeWorkout.exercises[exerciseIndex].sets.count else { continue }
            for setIndex in setStart..<activeWorkout.exercises[exerciseIndex].sets.count
            where !activeWorkout.exercises[exerciseIndex].sets[setIndex].isComplete {
                currentExerciseIndex = exerciseIndex
                currentSetIndex = setIndex
                persistActiveState()
                return
            }
        }

        for exerciseIndex in activeWorkout.exercises.indices {
            for setIndex in activeWorkout.exercises[exerciseIndex].sets.indices
            where !activeWorkout.exercises[exerciseIndex].sets[setIndex].isComplete {
                currentExerciseIndex = exerciseIndex
                currentSetIndex = setIndex
                persistActiveState()
                return
            }
        }
    }

    private func beginRest(seconds: Int) {
        cancelRest()
        guard seconds > 0 else { return }
        restEndsAt = Date().addingTimeInterval(TimeInterval(seconds))
        defaults.set(restEndsAt, forKey: StorageKey.restEndsAt)
        scheduleRestHaptic(after: TimeInterval(seconds))
    }

    private func cancelRest() {
        restTask?.cancel()
        restTask = nil
        restEndsAt = nil
        defaults.removeObject(forKey: StorageKey.restEndsAt)
    }

    private func restoreRestTimerIfNeeded() {
        guard let end = restEndsAt else { return }
        let remaining = end.timeIntervalSinceNow
        if remaining > 0 {
            scheduleRestHaptic(after: remaining)
        } else {
            cancelRest()
        }
    }

    private func scheduleRestHaptic(after interval: TimeInterval) {
        restTask?.cancel()
        restTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(interval, 0)))
            guard !Task.isCancelled, let self else { return }
            self.restEndsAt = nil
            self.defaults.removeObject(forKey: StorageKey.restEndsAt)
            WKInterfaceDevice.current().play(.notification)
        }
    }

    private func activateConnectivity() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        connectivitySession = session
        session.delegate = self
        session.activate()
    }

    private func acceptWeeklyPlan(_ data: Data) {
        do {
            let plan = try decoder.decode([WatchWorkoutPlan].self, from: data)
                .sorted { $0.scheduledDate < $1.scheduledDate }
            weeklyPlan = plan
            defaults.set(data, forKey: StorageKey.weeklyPlan)
            lastSyncDate = Date()
            syncError = nil
            WKInterfaceDevice.current().play(.success)
        } catch {
            syncError = "PLAN COULD NOT BE READ"
        }
    }

    private func receive(type: String?, payload: Data?) {
        guard let type, let payload else { return }
        switch type {
        case "weeklyPlan":
            acceptWeeklyPlan(payload)
        case "completedWorkout":
            acceptCompletedWorkout(payload)
        default:
            break
        }
    }

    private func sendEvent(_ event: [String: Any]) {
        guard let session = connectivitySession, session.activationState == .activated else {
            syncError = "IPHONE LINK IS STARTING"
            return
        }

        if session.isReachable {
            session.sendMessage(event, replyHandler: nil) { [weak self] _ in
                Task { @MainActor in
                    self?.queue(event, with: session)
                }
            }
        } else {
            queue(event, with: session)
        }
    }

    private func queue(_ event: [String: Any], with session: WCSession) {
        session.transferUserInfo(event)
    }

    private func restoreState() {
        let completedIDs = defaults.stringArray(forKey: StorageKey.completedPrescriptionIDs) ?? []
        completedPrescriptionIDs = Set(completedIDs.compactMap(UUID.init(uuidString:)))

        if let data = defaults.data(forKey: StorageKey.weeklyPlan),
           let plan = try? decoder.decode([WatchWorkoutPlan].self, from: data) {
            weeklyPlan = plan.sorted { $0.scheduledDate < $1.scheduledDate }
            lastSyncDate = Date()
        }
        if let data = defaults.data(forKey: StorageKey.activeWorkout),
           let workout = try? decoder.decode(WatchActiveWorkout.self, from: data),
           !completedPrescriptionIDs.contains(workout.prescriptionID) {
            activeWorkout = workout
        } else {
            defaults.removeObject(forKey: StorageKey.activeWorkout)
        }
        currentExerciseIndex = defaults.integer(forKey: StorageKey.currentExerciseIndex)
        currentSetIndex = defaults.integer(forKey: StorageKey.currentSetIndex)
        restEndsAt = defaults.object(forKey: StorageKey.restEndsAt) as? Date

        guard let activeWorkout,
              activeWorkout.exercises.indices.contains(currentExerciseIndex),
              activeWorkout.exercises[currentExerciseIndex].sets.indices.contains(currentSetIndex) else {
            currentExerciseIndex = 0
            currentSetIndex = 0
            return
        }
    }

    #if DEBUG
    /// A deterministic, launch-environment-only plan used to capture the Watch
    /// App Store image. It is absent from release builds.
    private func seedAppStoreScreenshotPlanIfNeeded() {
        guard ProcessInfo.processInfo.environment["FITNESS_BUDDY_APP_STORE_SCREENSHOTS"] == "1",
              weeklyPlan.isEmpty else { return }

        func exercise(
            id: UUID,
            exerciseID: String,
            name: String,
            muscle: String,
            equipment: String,
            weightKG: Double,
            reps: Int
        ) -> WatchExercisePrescription {
            WatchExercisePrescription(
                id: id,
                exercise: WatchExerciseDefinition(
                    id: exerciseID,
                    name: name,
                    muscle: muscle,
                    equipment: equipment,
                    cue: "Move with control and finish with two clean reps in reserve."
                ),
                sets: 3,
                repMin: reps,
                repMax: reps + 2,
                targetWeightKG: weightKG,
                restSeconds: 120,
                targetRIR: 2,
                measurementSystem: .imperial,
                incrementKG: 2.267_961_85,
                tracksNumericLoad: true
            )
        }

        func scheduledDate(daysFromToday: Int) -> Date {
            let today = Calendar.autoupdatingCurrent.startOfDay(for: Date())
            return Calendar.autoupdatingCurrent.date(
                byAdding: .day,
                value: daysFromToday,
                to: today
            ) ?? today
        }

        let upperA = WatchWorkoutPlan(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            title: "UPPER / A",
            subtitle: "Horizontal strength",
            scheduledDate: scheduledDate(daysFromToday: 0),
            estimatedMinutes: 53,
            focus: ["Chest", "Back", "Shoulders"],
            exercises: [
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!,
                    exerciseID: "barbell-bench",
                    name: "BARBELL BENCH PRESS",
                    muscle: "Chest",
                    equipment: "Barbell + rack",
                    weightKG: 61.2,
                    reps: 8
                ),
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000002")!,
                    exerciseID: "barbell-row",
                    name: "BARBELL ROW",
                    muscle: "Back",
                    equipment: "Barbell",
                    weightKG: 49.9,
                    reps: 8
                ),
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000003")!,
                    exerciseID: "shoulder-press",
                    name: "SEATED DUMBBELL PRESS",
                    muscle: "Shoulders",
                    equipment: "Dumbbells",
                    weightKG: 20.4,
                    reps: 10
                ),
            ],
            isAIEnhanced: true,
            rationale: "Adjusted from your recent performance and recovery."
        )
        let lowerA = WatchWorkoutPlan(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            title: "LOWER / A",
            subtitle: "Squat strength",
            scheduledDate: scheduledDate(daysFromToday: 2),
            estimatedMinutes: 47,
            focus: ["Legs", "Core"],
            exercises: [
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000004")!,
                    exerciseID: "back-squat",
                    name: "BARBELL BACK SQUAT",
                    muscle: "Legs",
                    equipment: "Barbell + rack",
                    weightKG: 83.9,
                    reps: 6
                ),
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000005")!,
                    exerciseID: "romanian-deadlift",
                    name: "ROMANIAN DEADLIFT",
                    muscle: "Legs",
                    equipment: "Barbell",
                    weightKG: 72.6,
                    reps: 8
                ),
                exercise(
                    id: UUID(uuidString: "20000000-0000-0000-0000-000000000006")!,
                    exerciseID: "dead-bug",
                    name: "DEAD BUG",
                    muscle: "Core",
                    equipment: "Bodyweight",
                    weightKG: 0,
                    reps: 10
                ),
            ],
            isAIEnhanced: true,
            rationale: "Lower-body volume held steady after two strong sessions."
        )

        weeklyPlan = [upperA, lowerA]
        lastSyncDate = Date()
    }
    #endif

    private func persistActiveState() {
        if let activeWorkout, let data = try? encoder.encode(activeWorkout) {
            defaults.set(data, forKey: StorageKey.activeWorkout)
        } else {
            defaults.removeObject(forKey: StorageKey.activeWorkout)
        }
        defaults.set(currentExerciseIndex, forKey: StorageKey.currentExerciseIndex)
        defaults.set(currentSetIndex, forKey: StorageKey.currentSetIndex)
    }

    private func acceptCompletedWorkout(_ data: Data) {
        guard let completed = try? decoder.decode(WatchCompletedWorkout.self, from: data),
              let prescriptionID = completed.prescriptionID else { return }
        completedPrescriptionIDs.insert(prescriptionID)
        persistCompletedPrescriptionIDs()
        if activeWorkout?.prescriptionID == prescriptionID {
            // The phone has already saved this prescription. End any stale Watch
            // builder without creating a second HealthKit workout.
            clearActiveWorkout(termination: .discard)
        }
        lastSyncDate = Date()
        syncError = nil
    }

    private func clearActiveWorkout(termination: WatchWorkoutTermination) {
        healthTermination = termination
        activeWorkout = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        cancelRest()
        persistActiveState()
    }

    private func persistCompletedPrescriptionIDs() {
        defaults.set(
            completedPrescriptionIDs.map(\.uuidString).sorted(),
            forKey: StorageKey.completedPrescriptionIDs
        )
    }
}

private struct WatchCompletedWorkout: Decodable {
    let prescriptionID: UUID?
}

extension WatchWorkoutStore: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.isReachable = session.isReachable
            self.syncError = error == nil ? nil : "IPHONE LINK FAILED"
            if activationState == .activated && self.weeklyPlan.isEmpty {
                self.requestPlanRefresh()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let type = userInfo["type"] as? String
        let payload = userInfo["payload"] as? Data
        Task { @MainActor in
            self.receive(type: type, payload: payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        let type = message["type"] as? String
        let payload = message["payload"] as? Data
        Task { @MainActor in
            self.receive(type: type, payload: payload)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        let type = applicationContext["type"] as? String
        let payload = applicationContext["payload"] as? Data
        Task { @MainActor in
            self.receive(type: type, payload: payload)
        }
    }
}
