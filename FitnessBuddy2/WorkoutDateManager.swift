import ActivityKit
import Foundation
import HealthKit
import SwiftUI
import UIKit
import WatchConnectivity

enum FitnessHaptics {
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func setComplete() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 0.86)
    }

    static func personalRecord() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

enum FitnessFormatters {
    static func weight(_ kilograms: Double, units: MeasurementSystem, includeUnit: Bool = true) -> String {
        let value = units == .imperial ? kilograms * 2.204_622_621_8 : kilograms
        let rounded = value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
        return includeUnit ? "\(rounded) \(units.weightUnit)" : rounded
    }

    static func duration(_ interval: TimeInterval) -> String {
        let total = max(Int(interval), 0)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func compactVolume(_ kilograms: Double, units: MeasurementSystem) -> String {
        let value = units == .imperial ? kilograms * 2.204_622_621_8 : kilograms
        if value >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return String(format: "%.0f", value)
    }
}

@MainActor
final class HealthKitManager: ObservableObject {
    enum Status: Equatable {
        case unavailable
        case notRequested
        case authorized
        case needsSettings

        var label: String {
            switch self {
            case .unavailable: "Unavailable"
            case .notRequested: "Not connected"
            case .authorized: "Connected"
            case .needsSettings: "Review settings"
            }
        }
    }

    @Published private(set) var status: Status = HKHealthStore.isHealthDataAvailable() ? .notRequested : .unavailable
    @Published private(set) var recentHealthWorkouts: [HKWorkout] = []
    @Published private(set) var lastError: String?

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            return false
        }

        // Ask only for what the app actually uses: it writes the strength
        // workouts you complete here, and reads back the workout list so your
        // history stays consistent with Health.
        let workout = HKObjectType.workoutType()
        let read: Set<HKObjectType> = [workout]

        do {
            try await healthStore.requestAuthorization(toShare: [workout], read: read)
            status = healthStore.authorizationStatus(for: workout) == .sharingAuthorized ? .authorized : .needsSettings
            if status == .authorized {
                installWorkoutObserver()
                await refreshRecentWorkouts()
            }
            return status == .authorized
        } catch {
            lastError = error.localizedDescription
            status = .needsSettings
            return false
        }
    }

    func restoreAuthorizationState() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            status = .unavailable
            return
        }
        let workout = HKObjectType.workoutType()
        let current = healthStore.authorizationStatus(for: workout)
        status = current == .sharingAuthorized ? .authorized : .notRequested
        if status == .authorized {
            installWorkoutObserver()
            await refreshRecentWorkouts()
        }
    }

    func save(_ session: WorkoutSession) async -> UUID? {
        guard status == .authorized, let end = session.endedAt else { return nil }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: healthStore, configuration: configuration, device: .local())

        do {
            try await beginCollection(builder, at: session.startedAt)
            try await builder.addMetadata([
                HKMetadataKeyExternalUUID: session.id.uuidString,
                HKMetadataKeyIndoorWorkout: true,
                "com.fitnessbuddy.workout.title": session.title,
                "com.fitnessbuddy.workout.volumeKG": session.volume,
                "com.fitnessbuddy.workout.completedSets": session.completedSetCount,
            ])
            try await endCollection(builder, at: end)
            let workout = try await finish(builder)
            await refreshRecentWorkouts()
            return workout?.uuid
        } catch {
            lastError = error.localizedDescription
            return nil
        }
    }

    func refreshRecentWorkouts() async {
        let workout = HKObjectType.workoutType()
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workout, predicate: nil, limit: 20, sortDescriptors: [sort]) { [weak self] _, samples, _ in
                let values = samples as? [HKWorkout] ?? []
                Task { @MainActor in
                    self?.recentHealthWorkouts = values
                    continuation.resume()
                }
            }
            healthStore.execute(query)
        }
    }

    private func installWorkoutObserver() {
        guard observerQuery == nil else { return }
        let type = HKObjectType.workoutType()
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] _, completion, _ in
            Task { @MainActor in
                await self?.refreshRecentWorkouts()
                completion()
            }
        }
        observerQuery = query
        healthStore.execute(query)
    }

    private func beginCollection(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.beginCollection(withStart: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthKitError.operationFailed) }
            }
        }
    }

    private func endCollection(_ builder: HKWorkoutBuilder, at date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            builder.endCollection(withEnd: date) { success, error in
                if let error { continuation.resume(throwing: error) }
                else if success { continuation.resume(returning: ()) }
                else { continuation.resume(throwing: HealthKitError.operationFailed) }
            }
        }
    }

    private func finish(_ builder: HKWorkoutBuilder) async throws -> HKWorkout? {
        try await withCheckedThrowingContinuation { continuation in
            builder.finishWorkout { workout, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: workout) }
            }
        }
    }

    private enum HealthKitError: Error { case operationFailed }
}

struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var setNumber: Int
        var totalSets: Int
        var completedSets: Int
        var totalWorkoutSets: Int
        var restEndsAt: Date?
        var isComplete: Bool
    }

    var workoutTitle: String
    var sessionID: String
    var startedAt: Date
}

@MainActor
final class WorkoutLiveActivityManager: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var lastError: String?

    private var activity: Activity<WorkoutActivityAttributes>?

    init() {
        activity = Activity<WorkoutActivityAttributes>.activities.first
        isActive = activity != nil
    }

    func start(session: WorkoutSession, exerciseIndex: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if let recovered = Activity<WorkoutActivityAttributes>.activities.first(where: {
            $0.attributes.sessionID == session.id.uuidString
        }) {
            activity = recovered
            isActive = true
            update(session: session, exerciseIndex: exerciseIndex, restEndsAt: nil)
            endStaleActivities(except: recovered.id)
            return
        }

        guard activity == nil else {
            recover(
                session: session,
                exerciseIndex: exerciseIndex,
                restEndsAt: nil
            )
            return
        }

        let state = contentState(session: session, exerciseIndex: exerciseIndex, restEndsAt: nil)
        let attributes = WorkoutActivityAttributes(
            workoutTitle: session.title,
            sessionID: session.id.uuidString,
            startedAt: session.startedAt
        )
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            isActive = true
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Reconnects to ActivityKit state after the process is relaunched. Any
    /// orphaned activity is dismissed so a stale workout cannot remain on the
    /// Lock Screen or block the next session.
    func recover(
        session: WorkoutSession?,
        exerciseIndex: Int,
        restEndsAt: Date?
    ) {
        let runningActivities = Activity<WorkoutActivityAttributes>.activities

        guard let session else {
            activity = nil
            isActive = false
            runningActivities.forEach(endImmediately)
            return
        }

        if let recovered = runningActivities.first(where: {
            $0.attributes.sessionID == session.id.uuidString
        }) {
            activity = recovered
            isActive = true
            update(
                session: session,
                exerciseIndex: exerciseIndex,
                restEndsAt: restEndsAt
            )
            endStaleActivities(except: recovered.id)
        } else {
            activity = nil
            isActive = false
            runningActivities.forEach(endImmediately)
            start(session: session, exerciseIndex: exerciseIndex)
            update(
                session: session,
                exerciseIndex: exerciseIndex,
                restEndsAt: restEndsAt
            )
        }
    }

    func update(session: WorkoutSession, exerciseIndex: Int, restEndsAt: Date?) {
        guard let activity else { return }
        let state = contentState(session: session, exerciseIndex: exerciseIndex, restEndsAt: restEndsAt)
        Task {
            await activity.update(ActivityContent(state: state, staleDate: restEndsAt))
        }
    }

    func end(session: WorkoutSession) {
        guard let activity else { return }
        let state = contentState(session: session, exerciseIndex: max(session.exercises.count - 1, 0), restEndsAt: nil, complete: true)
        Task {
            await activity.end(
                ActivityContent(state: state, staleDate: nil),
                dismissalPolicy: .after(Date().addingTimeInterval(12))
            )
            self.activity = nil
            self.isActive = false
        }
    }

    func cancel() {
        let runningActivities = Activity<WorkoutActivityAttributes>.activities
        guard !runningActivities.isEmpty || activity != nil else { return }
        self.activity = nil
        isActive = false
        Task {
            for runningActivity in runningActivities {
                await runningActivity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func endStaleActivities(except retainedID: String) {
        Activity<WorkoutActivityAttributes>.activities
            .filter { $0.id != retainedID }
            .forEach(endImmediately)
    }

    private func endImmediately(_ runningActivity: Activity<WorkoutActivityAttributes>) {
        Task {
            await runningActivity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func contentState(
        session: WorkoutSession,
        exerciseIndex: Int,
        restEndsAt: Date?,
        complete: Bool = false
    ) -> WorkoutActivityAttributes.ContentState {
        let safeIndex = min(max(exerciseIndex, 0), max(session.exercises.count - 1, 0))
        let exercise = session.exercises.indices.contains(safeIndex) ? session.exercises[safeIndex] : nil
        return WorkoutActivityAttributes.ContentState(
            exerciseName: exercise?.exercise.name ?? session.title,
            setNumber: (exercise?.sets.firstIndex(where: { !$0.isComplete }) ?? max((exercise?.sets.count ?? 1) - 1, 0)) + 1,
            totalSets: exercise?.sets.count ?? 0,
            completedSets: session.completedSetCount,
            totalWorkoutSets: session.totalSetCount,
            restEndsAt: restEndsAt,
            isComplete: complete
        )
    }
}

@MainActor
final class WatchSyncManager: NSObject, ObservableObject {
    @Published private(set) var isSupported = WCSession.isSupported()
    @Published private(set) var isReachable = false
    @Published private(set) var activationState: WCSessionActivationState = .notActivated
    @Published private(set) var lastSyncDate: Date?

    var onEvent: ((WatchIncomingEvent) -> Void)?

    private let session: WCSession? = WCSession.isSupported() ? .default : nil

    override init() {
        super.init()
        session?.delegate = self
        session?.activate()
    }

    func sync(plan: [WorkoutPrescription]) {
        guard let session, session.activationState == .activated,
              let data = try? JSONEncoder().encode(plan) else { return }
        session.transferUserInfo(["type": "weeklyPlan", "payload": data])
        lastSyncDate = Date()
    }

    func sync(completed workout: WorkoutSession) {
        guard let session, session.activationState == .activated,
              let data = try? JSONEncoder().encode(workout) else { return }
        session.transferUserInfo(["type": "completedWorkout", "payload": data])
        lastSyncDate = Date()
    }

    private func receive(_ event: WatchIncomingEvent) {
        lastSyncDate = Date()
        onEvent?(event)
    }
}

enum WatchIncomingEvent: Sendable {
    case completedSet(WatchCompletedSetEvent)
    case workoutStarted(workoutID: String, startedAt: Date)
    case workoutCompleted(WatchCompletedWorkoutEvent)
    case workoutDiscarded(workoutID: String, discardedAt: Date)
    case requestWeeklyPlan

    init?(dictionary: [String: Any]) {
        guard let type = dictionary["type"] as? String else { return nil }
        switch type {
        case "completedSet":
            guard let event = WatchCompletedSetEvent(dictionary: dictionary) else { return nil }
            self = .completedSet(event)
        case "watchWorkoutStarted":
            guard let workoutID = dictionary["workoutID"] as? String else { return nil }
            self = .workoutStarted(
                workoutID: workoutID,
                startedAt: dictionary["startedAt"] as? Date ?? Date()
            )
        case "watchWorkoutCompleted":
            guard let event = WatchCompletedWorkoutEvent(dictionary: dictionary) else { return nil }
            self = .workoutCompleted(event)
        case "watchWorkoutDiscarded":
            guard let workoutID = dictionary["workoutID"] as? String else { return nil }
            self = .workoutDiscarded(
                workoutID: workoutID,
                discardedAt: dictionary["discardedAt"] as? Date ?? Date()
            )
        case "requestWeeklyPlan":
            self = .requestWeeklyPlan
        default:
            return nil
        }
    }
}

struct WatchCompletedWorkoutEvent: Hashable, Sendable {
    let workoutID: String
    let startedAt: Date
    let endedAt: Date
    let completedSets: [WatchCompletedSetEvent]

    init?(dictionary: [String: Any]) {
        guard dictionary["type"] as? String == "watchWorkoutCompleted",
              let workoutID = dictionary["workoutID"] as? String
        else { return nil }

        let rawSnapshots = dictionary["completedSetSnapshots"] as? [[String: Any]] ?? []
        let snapshots = rawSnapshots.compactMap { snapshot -> WatchCompletedSetEvent? in
            var payload = snapshot
            payload["type"] = "completedSet"
            payload["workoutID"] = workoutID
            return WatchCompletedSetEvent(dictionary: payload)
        }
        // Never silently finish a session after dropping a malformed set snapshot.
        guard snapshots.count == rawSnapshots.count else { return nil }

        let endedAt = dictionary["endedAt"] as? Date ?? Date()
        let startedAt = dictionary["startedAt"] as? Date ?? endedAt
        self.workoutID = workoutID
        self.startedAt = min(startedAt, endedAt)
        self.endedAt = endedAt
        self.completedSets = snapshots
    }
}

struct WatchCompletedSetEvent: Hashable, Sendable {
    let eventID: String
    let workoutID: String
    let exerciseID: String
    let setNumber: Int
    let weightKG: Double
    let reps: Int
    let reportedRIR: Int
    let completedAt: Date
    let restSeconds: Int

    init?(dictionary: [String: Any]) {
        guard dictionary["type"] as? String == "completedSet",
              let eventID = dictionary["eventID"] as? String,
              let workoutID = dictionary["workoutID"] as? String,
              let exerciseID = dictionary["exerciseID"] as? String,
              let setNumber = Self.int(dictionary["setNumber"]),
              let weightKG = Self.double(dictionary["weightKG"]),
              let reps = Self.int(dictionary["reps"]),
              let reportedRIR = Self.int(dictionary["reportedRIR"]),
              let restSeconds = Self.int(dictionary["restSeconds"]),
              (0...5).contains(reportedRIR)
        else { return nil }

        self.eventID = eventID
        self.workoutID = workoutID
        self.exerciseID = exerciseID
        self.setNumber = setNumber
        self.weightKG = weightKG
        self.reps = reps
        self.reportedRIR = reportedRIR
        self.completedAt = dictionary["completedAt"] as? Date ?? Date()
        self.restSeconds = restSeconds
    }

    private static func int(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        return (value as? NSNumber)?.doubleValue
    }
}

extension WatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            self.activationState = activationState
            self.isReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let event = WatchIncomingEvent(dictionary: message) else { return }
        Task { @MainActor in self.receive(event) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let event = WatchIncomingEvent(dictionary: userInfo) else { return }
        Task { @MainActor in self.receive(event) }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
