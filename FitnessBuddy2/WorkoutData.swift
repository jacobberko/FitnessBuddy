import Foundation
import SwiftUI

enum MuscleGroup: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case conditioning = "Conditioning"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .chest: "figure.strengthtraining.traditional"
        case .back: "figure.climbing"
        case .legs: "figure.squat"
        case .shoulders: "dumbbell.fill"
        case .arms: "figure.mixed.cardio"
        case .core: "figure.core.training"
        case .conditioning: "figure.run"
        }
    }
}

enum MovementPattern: String, Codable, CaseIterable, Hashable, Sendable {
    case squat
    case hinge
    case singleLeg
    case horizontalPush
    case verticalPush
    case horizontalPull
    case verticalPull
    case lateralRaise
    case armFlexion
    case armExtension
    case calves
    case coreAntiExtension
    case coreAntiRotation
}

struct ProgramSummary: Codable, Hashable, Sendable {
    var generatedAt: Date
    var weekNumber: Int
    var blockLengthWeeks: Int
    var splitName: String
    var goal: FitnessGoal
    var targetRIR: Int
    var weeklySetsByMuscle: [MuscleGroup: Int]
    var rationale: String
    var progressionRule: String
    var evidenceNote: String

    var totalWorkingSets: Int { weeklySetsByMuscle.values.reduce(0, +) }
}

enum AdaptationDirection: String, Codable, Hashable, Sendable {
    case calibrate
    case hold
    case increase
    case reduce
}

struct AdaptationDecision: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exerciseID: String
    var exerciseName: String
    var direction: AdaptationDirection
    var previousLoadKG: Double
    var nextLoadKG: Double
    var reason: String
    var createdAt: Date = Date()
}

struct ExerciseDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let muscle: MuscleGroup
    let equipment: String
    let cue: String
}

struct ExercisePrescription: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    let exercise: ExerciseDefinition
    var sets: Int
    var repMin: Int
    var repMax: Int
    var targetWeightKG: Double
    var restSeconds: Int
    var targetRIR: Int? = nil
    var loadSource: String? = nil
    var decisionNote: String? = nil
    /// Transport metadata used by Apple Watch. Weight values remain canonical
    /// kilograms while this tells the Watch how to present them.
    var measurementSystem: String? = nil
    /// The smallest sensible equipment jump for this movement, in kilograms.
    var incrementKG: Double? = nil
    var tracksNumericLoad: Bool? = nil

    var repLabel: String { repMin == repMax ? "\(repMin)" : "\(repMin)–\(repMax)" }
    var effectiveTargetRIR: Int { targetRIR ?? 2 }
}

struct WorkoutPrescription: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String
    var scheduledDate: Date
    var estimatedMinutes: Int
    var focus: [MuscleGroup]
    var exercises: [ExercisePrescription]
    var isAIEnhanced: Bool = false
    var rationale: String = ""

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        scheduledDate: Date,
        estimatedMinutes: Int,
        focus: [MuscleGroup],
        exercises: [ExercisePrescription],
        isAIEnhanced: Bool = false,
        rationale: String = ""
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.scheduledDate = scheduledDate
        self.estimatedMinutes = estimatedMinutes
        self.focus = focus
        self.exercises = exercises
        self.isAIEnhanced = isAIEnhanced
        self.rationale = rationale
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, subtitle, scheduledDate, estimatedMinutes, focus, exercises, isAIEnhanced, rationale
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try values.decode(String.self, forKey: .title)
        subtitle = try values.decode(String.self, forKey: .subtitle)
        scheduledDate = try values.decode(Date.self, forKey: .scheduledDate)
        estimatedMinutes = try values.decode(Int.self, forKey: .estimatedMinutes)
        focus = try values.decode([MuscleGroup].self, forKey: .focus)
        exercises = try values.decode([ExercisePrescription].self, forKey: .exercises)
        isAIEnhanced = try values.decodeIfPresent(Bool.self, forKey: .isAIEnhanced) ?? false
        rationale = try values.decodeIfPresent(String.self, forKey: .rationale) ?? ""
    }
}

struct WorkoutSetLog: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var setNumber: Int
    var targetRepMin: Int
    var targetRepMax: Int
    var weightKG: Double
    var reps: Int
    var isComplete: Bool = false
    var completedAt: Date?
    var restSeconds: Int
    var targetRIR: Int? = nil
    var reportedRIR: Int? = nil

    var volume: Double { isComplete ? weightKG * Double(reps) : 0 }
    var effectiveTargetRIR: Int { targetRIR ?? 2 }
    var effectiveReportedRIR: Int { reportedRIR ?? effectiveTargetRIR }
}

struct SessionExercise: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    let exercise: ExerciseDefinition
    var cue: String
    var sets: [WorkoutSetLog]
    var loadSource: String? = nil
    var decisionNote: String? = nil

    var isComplete: Bool { !sets.isEmpty && sets.allSatisfy(\.isComplete) }
    var volume: Double { sets.reduce(0) { $0 + $1.volume } }
}

enum WorkoutRecordingOwner: String, Codable, Hashable, Sendable {
    case phone
    case watch
}

struct WorkoutSession: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var prescriptionID: UUID?
    var title: String
    var focus: [MuscleGroup]
    var startedAt: Date
    var endedAt: Date?
    var exercises: [SessionExercise]
    var healthKitUUID: UUID?
    var isLegacySummary: Bool = false
    /// The device responsible for creating the HealthKit workout. Exercise logs
    /// still sync both ways, but only this owner may save the HKWorkout.
    var recordingOwner: WorkoutRecordingOwner = .phone
    var isWatchOriginated: Bool { recordingOwner == .watch }

    var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
    var volume: Double { exercises.reduce(0) { $0 + $1.volume } }
    var completedSetCount: Int { exercises.flatMap(\.sets).filter(\.isComplete).count }
    var totalSetCount: Int { exercises.flatMap(\.sets).count }

    init(
        id: UUID = UUID(),
        prescriptionID: UUID? = nil,
        title: String,
        focus: [MuscleGroup],
        startedAt: Date,
        endedAt: Date? = nil,
        exercises: [SessionExercise],
        healthKitUUID: UUID? = nil,
        isLegacySummary: Bool = false,
        isWatchOriginated: Bool = false,
        recordingOwner: WorkoutRecordingOwner? = nil
    ) {
        self.id = id
        self.prescriptionID = prescriptionID
        self.title = title
        self.focus = focus
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exercises = exercises
        self.healthKitUUID = healthKitUUID
        self.isLegacySummary = isLegacySummary
        self.recordingOwner = recordingOwner ?? (isWatchOriginated ? .watch : .phone)
    }

    private enum CodingKeys: String, CodingKey {
        case id, prescriptionID, title, focus, startedAt, endedAt, exercises, healthKitUUID, isLegacySummary
        case recordingOwner, isWatchOriginated
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        prescriptionID = try values.decodeIfPresent(UUID.self, forKey: .prescriptionID)
        title = try values.decode(String.self, forKey: .title)
        focus = try values.decode([MuscleGroup].self, forKey: .focus)
        startedAt = try values.decode(Date.self, forKey: .startedAt)
        endedAt = try values.decodeIfPresent(Date.self, forKey: .endedAt)
        exercises = try values.decode([SessionExercise].self, forKey: .exercises)
        healthKitUUID = try values.decodeIfPresent(UUID.self, forKey: .healthKitUUID)
        isLegacySummary = try values.decodeIfPresent(Bool.self, forKey: .isLegacySummary) ?? false
        recordingOwner = try values.decodeIfPresent(WorkoutRecordingOwner.self, forKey: .recordingOwner)
            ?? ((try values.decodeIfPresent(Bool.self, forKey: .isWatchOriginated)) == true ? .watch : .phone)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encodeIfPresent(prescriptionID, forKey: .prescriptionID)
        try values.encode(title, forKey: .title)
        try values.encode(focus, forKey: .focus)
        try values.encode(startedAt, forKey: .startedAt)
        try values.encodeIfPresent(endedAt, forKey: .endedAt)
        try values.encode(exercises, forKey: .exercises)
        try values.encodeIfPresent(healthKitUUID, forKey: .healthKitUUID)
        try values.encode(isLegacySummary, forKey: .isLegacySummary)
        try values.encode(recordingOwner, forKey: .recordingOwner)
        // Retain this key so older app versions can safely decode Watch-owned sessions.
        try values.encode(isWatchOriginated, forKey: .isWatchOriginated)
    }
}

enum PersonalRecordMetric: String, Codable, Sendable {
    case weight = "HEAVIEST"
    case estimatedOneRepMax = "EST. 1RM"
}

struct PersonalRecord: Codable, Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var exerciseID: String
    var exerciseName: String
    var metric: PersonalRecordMetric
    var valueKG: Double
    var reps: Int
    var achievedAt: Date
    var sessionID: UUID

    init(
        id: UUID = UUID(),
        exerciseID: String,
        exerciseName: String,
        metric: PersonalRecordMetric,
        valueKG: Double,
        reps: Int,
        achievedAt: Date,
        sessionID: UUID
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.metric = metric
        self.valueKG = valueKG
        self.reps = reps
        self.achievedAt = achievedAt
        self.sessionID = sessionID
    }

    private enum CodingKeys: String, CodingKey {
        case id, exerciseID, exerciseName, metric, valueKG, reps, achievedAt, sessionID
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseID = try values.decode(String.self, forKey: .exerciseID)
        exerciseName = try values.decode(String.self, forKey: .exerciseName)
        metric = try values.decodeIfPresent(PersonalRecordMetric.self, forKey: .metric) ?? .weight
        valueKG = try values.decode(Double.self, forKey: .valueKG)
        reps = try values.decode(Int.self, forKey: .reps)
        achievedAt = try values.decode(Date.self, forKey: .achievedAt)
        sessionID = try values.decode(UUID.self, forKey: .sessionID)
    }
}

struct CoachMessage: Codable, Identifiable, Hashable, Sendable {
    enum Role: String, Codable, Sendable { case coach, user }

    var id: UUID = UUID()
    var role: Role
    var text: String
    var createdAt: Date = Date()
}

struct CoachPlanExercise: Codable, Hashable, Sendable {
    var exerciseID: String
    var sets: Int
    var repMin: Int
    var repMax: Int
    var targetWeightKG: Double
    var restSeconds: Int
    var targetRIR: Int? = nil
}

struct CoachPlanDay: Codable, Hashable, Sendable {
    var title: String
    var subtitle: String
    var dayOffset: Int
    var estimatedMinutes: Int
    var rationale: String
    var exercises: [CoachPlanExercise]
}

struct CoachAPIResponse: Codable, Hashable, Sendable {
    var reply: String
    var insight: String
    var plan: [CoachPlanDay]
}

struct VolumePoint: Identifiable, Hashable, Sendable {
    var id: Date { date }
    let date: Date
    let volumeKG: Double
}

@MainActor
final class WorkoutData: ObservableObject {
    @Published private(set) var weeklyPlan: [WorkoutPrescription] = []
    @Published private(set) var programSummary: ProgramSummary?
    @Published private(set) var adaptationDecisions: [AdaptationDecision] = []
    @Published private(set) var completedWorkouts: [WorkoutSession] = []
    @Published var activeSession: WorkoutSession?
    @Published var activeExerciseIndex = 0
    @Published var restEndsAt: Date?
    @Published private(set) var personalRecords: [PersonalRecord] = []
    @Published var coachMessages: [CoachMessage] = [
        CoachMessage(role: .coach, text: "I’m watching your training pattern. Finish a session and I’ll tune next week around your performance."),
    ]
    @Published var coachInsight = "Your week is balanced. Start with the recommended session and leave one clean rep in reserve."
    @Published var isCoachThinking = false
    @Published private(set) var pendingCoachProposal: CoachAPIResponse?

    private var planSignature = ""
    private let calendar = Calendar.autoupdatingCurrent
    private let persistenceURL: URL

    init(persistenceURL: URL? = nil, migrateLegacy: Bool = true) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = base.appendingPathComponent("FitnessBuddy", isDirectory: true)
        let resolvedURL = persistenceURL ?? folder.appendingPathComponent("training-state-v3.json")
        try? FileManager.default.createDirectory(
            at: resolvedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        self.persistenceURL = resolvedURL
        if ProcessInfo.processInfo.environment["FITNESS_BUDDY_UI_TEST_RESET"] == "1" {
            try? FileManager.default.removeItem(at: resolvedURL)
        }
        load()
        if migrateLegacy {
            migrateLegacyHistoryIfNeeded()
        }
        #if DEBUG
        seedAppStoreScreenshotHistoryIfNeeded()
        #endif
    }

    var todayWorkout: WorkoutPrescription? {
        let today = calendar.startOfDay(for: Date())
        let completedPrescriptionIDs = Set(completedWorkouts.compactMap(\.prescriptionID))
        let remaining = weeklyPlan.filter { !completedPrescriptionIDs.contains($0.id) }
        return remaining.min { lhs, rhs in
            abs(calendar.startOfDay(for: lhs.scheduledDate).timeIntervalSince(today))
                < abs(calendar.startOfDay(for: rhs.scheduledDate).timeIntervalSince(today))
        }
    }

    var workoutProgress: Double {
        guard let activeSession, activeSession.totalSetCount > 0 else { return 0 }
        return Double(activeSession.completedSetCount) / Double(activeSession.totalSetCount)
    }

    var currentExercise: SessionExercise? {
        guard let activeSession, activeSession.exercises.indices.contains(activeExerciseIndex) else { return nil }
        return activeSession.exercises[activeExerciseIndex]
    }

    var isCurrentExerciseComplete: Bool { currentExercise?.isComplete == true }

    var isWorkoutReadyToFinish: Bool {
        guard let activeSession else { return false }
        return activeSession.exercises.allSatisfy(\.isComplete)
    }

    var weeklyCompletedCount: Int {
        completedWorkouts.filter { calendar.isDate($0.startedAt, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }

    var weeklyVolumeKG: Double {
        completedWorkouts
            .filter { calendar.isDate($0.startedAt, equalTo: Date(), toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.volume }
    }

    var streak: Int {
        let uniqueDays = Set(completedWorkouts.map { calendar.startOfDay(for: $0.startedAt) })
        guard !uniqueDays.isEmpty else { return 0 }
        var cursor = calendar.startOfDay(for: Date())
        if !uniqueDays.contains(cursor) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        var result = 0
        while uniqueDays.contains(cursor) {
            result += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return result
    }

    var readiness: Double {
        guard let latest = completedWorkouts.map(\.startedAt).max() else { return 0.86 }
        let hours = Date().timeIntervalSince(latest) / 3_600
        let recovery = min(max(hours / 48, 0.35), 1)
        let volumePenalty = min(weeklyVolumeKG / 45_000, 0.18)
        return min(max(recovery - volumePenalty + 0.12, 0.35), 0.98)
    }

    func configure(for profile: UserProfileSnapshot, force: Bool = false) {
        let equipment = profile.equipment.map(\.rawValue).sorted().joined(separator: ",")
        let constraints = profile.constraints.map(\.rawValue).sorted().joined(separator: ",")
        let weekdays = profile.preferredWeekdays.sorted().map(String.init).joined(separator: ",")
        let baselines = profile.baselines
            .sorted { $0.exerciseID < $1.exerciseID }
            .map { "\($0.exerciseID):\($0.weightKG):\($0.reps):\($0.rir ?? -1)" }
            .joined(separator: ",")
        let signature = [
            "engine-v6", profile.experience.rawValue, profile.goal.rawValue,
            String(profile.sessionsPerWeek), String(profile.sessionMinutes), String(profile.trainingAgeMonths),
            profile.measurementSystem.rawValue, weekdays, equipment, constraints, baselines, String(profile.recoveryRating),
        ].joined(separator: "|")
        let today = calendar.startOfDay(for: Date())
        let cycleExpired = weeklyPlan
            .map { calendar.startOfDay(for: $0.scheduledDate) }
            .max()
            .map { today > $0 } ?? true
        guard force || weeklyPlan.isEmpty || signature != planSignature || cycleExpired else { return }
        planSignature = signature
        weeklyPlan = buildPlan(for: profile)
        persist()
    }

    @discardableResult
    func startWorkout(
        _ prescription: WorkoutPrescription,
        startedAt: Date = Date(),
        fromWatch: Bool = false
    ) -> Bool {
        guard activeSession == nil,
              !completedWorkouts.contains(where: { $0.prescriptionID == prescription.id })
        else { return false }
        let exercises = prescription.exercises.map { item in
            SessionExercise(
                exercise: item.exercise,
                cue: item.exercise.cue,
                sets: (1...item.sets).map { number in
                    WorkoutSetLog(
                        setNumber: number,
                        targetRepMin: item.repMin,
                        targetRepMax: item.repMax,
                        weightKG: item.targetWeightKG,
                        reps: item.repMin,
                        restSeconds: item.restSeconds,
                        targetRIR: item.targetRIR,
                        reportedRIR: nil
                    )
                },
                loadSource: item.loadSource,
                decisionNote: item.decisionNote
            )
        }
        activeSession = WorkoutSession(
            prescriptionID: prescription.id,
            title: prescription.title,
            focus: prescription.focus,
            startedAt: startedAt,
            exercises: exercises,
            isWatchOriginated: fromWatch
        )
        activeExerciseIndex = 0
        restEndsAt = nil
        persist()
        return true
    }

    func updateWeight(exerciseIndex: Int, setIndex: Int, displayValue: Double, units: MeasurementSystem) {
        mutateSet(exerciseIndex: exerciseIndex, setIndex: setIndex) { set in
            set.weightKG = units == .imperial ? displayValue / 2.204_622_621_8 : displayValue
        }
    }

    func updateReps(exerciseIndex: Int, setIndex: Int, reps: Int) {
        mutateSet(exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.reps = max(0, reps) }
    }

    func updateRIR(exerciseIndex: Int, setIndex: Int, rir: Int) {
        mutateSet(exerciseIndex: exerciseIndex, setIndex: setIndex) { $0.reportedRIR = min(max(rir, 0), 5) }
    }

    @discardableResult
    func toggleSet(exerciseIndex: Int, setIndex: Int) -> Bool {
        guard var session = activeSession,
              session.exercises.indices.contains(exerciseIndex),
              session.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return false }

        var set = session.exercises[exerciseIndex].sets[setIndex]
        guard set.isComplete || set.reportedRIR != nil else { return false }
        set.isComplete.toggle()
        set.completedAt = set.isComplete ? Date() : nil
        session.exercises[exerciseIndex].sets[setIndex] = set
        activeSession = session

        var achievedPR = false
        if set.isComplete {
            achievedPR = registerPRIfNeeded(
                exercise: session.exercises[exerciseIndex].exercise,
                set: set,
                sessionID: session.id
            )
            restEndsAt = Date().addingTimeInterval(TimeInterval(set.restSeconds))
        }
        persist()
        return achievedPR
    }

    func skipRest() {
        restEndsAt = nil
        persist()
    }

    func moveToExercise(_ index: Int) {
        guard let activeSession, activeSession.exercises.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
            activeExerciseIndex = index
        }
    }

    func moveToNextExercise() {
        guard let activeSession else { return }
        let next = min(activeExerciseIndex + 1, activeSession.exercises.count - 1)
        moveToExercise(next)
    }

    func finishActiveWorkout(endedAt: Date = Date()) -> WorkoutSession? {
        guard var session = activeSession else { return nil }
        session.endedAt = endedAt
        completedWorkouts.insert(session, at: 0)
        activeSession = nil
        activeExerciseIndex = 0
        restEndsAt = nil
        updatePrescriptionAfter(session)
        updateLocalInsight(after: session)
        persist()
        return session
    }

    func discardActiveWorkout() {
        activeSession = nil
        activeExerciseIndex = 0
        restEndsAt = nil
        persist()
    }

    @discardableResult
    func startWorkoutFromWatch(workoutID: String, startedAt: Date) -> Bool {
        if var activeSession {
            guard activeSession.id.uuidString == workoutID
                    || activeSession.prescriptionID?.uuidString == workoutID
            else { return false }
            // A Watch start explicitly transfers HealthKit recording ownership.
            // This also covers a workout opened on iPhone moments before the Watch starts it.
            activeSession.recordingOwner = .watch
            activeSession.startedAt = min(activeSession.startedAt, startedAt)
            self.activeSession = activeSession
            persist()
            return true
        }
        guard let prescription = weeklyPlan.first(where: { $0.id.uuidString == workoutID }) else { return false }
        return startWorkout(prescription, startedAt: startedAt, fromWatch: true)
    }

    func finishWorkoutFromWatch(workoutID: String, endedAt: Date) -> WorkoutSession? {
        guard startWorkoutFromWatch(workoutID: workoutID, startedAt: endedAt),
              let activeSession,
              activeSession.id.uuidString == workoutID || activeSession.prescriptionID?.uuidString == workoutID
        else { return nil }
        return finishActiveWorkout(endedAt: endedAt)
    }

    @discardableResult
    func discardWorkoutFromWatch(workoutID: String) -> Bool {
        let existingStart = activeSession?.startedAt ?? Date()
        guard startWorkoutFromWatch(workoutID: workoutID, startedAt: existingStart),
              let activeSession,
              activeSession.id.uuidString == workoutID || activeSession.prescriptionID?.uuidString == workoutID,
              activeSession.recordingOwner == .watch
        else { return false }
        discardActiveWorkout()
        return true
    }

    func openWorkoutDeepLink(sessionID: String) {
        guard let session = activeSession, session.id.uuidString == sessionID else { return }
        activeExerciseIndex = session.exercises.firstIndex(where: { !$0.isComplete }) ?? 0
    }

    /// Accepts a set completed on Apple Watch. If the workout was started from
    /// the Watch, the matching prescription becomes the active phone session
    /// before the set is merged.
    @discardableResult
    func applyWatchCompletedSet(_ event: WatchCompletedSetEvent) -> Bool {
        if activeSession == nil,
           let prescription = weeklyPlan.first(where: { $0.id.uuidString == event.workoutID }) {
            guard startWorkout(prescription, fromWatch: true) else { return false }
        } else {
            // Connectivity delivery is not ordered across immediate messages and
            // queued transfers. A set may beat the explicit start event.
            guard startWorkoutFromWatch(
                workoutID: event.workoutID,
                startedAt: event.completedAt
            ) else { return false }
        }

        guard var session = activeSession,
              session.id.uuidString == event.workoutID || session.prescriptionID?.uuidString == event.workoutID,
              let exerciseIndex = session.exercises.firstIndex(where: { $0.exercise.id == event.exerciseID }),
              let setIndex = session.exercises[exerciseIndex].sets.firstIndex(where: { $0.setNumber == event.setNumber })
        else { return false }

        var set = session.exercises[exerciseIndex].sets[setIndex]
        set.weightKG = max(event.weightKG, 0)
        set.reps = max(event.reps, 0)
        set.reportedRIR = min(max(event.reportedRIR, 0), 5)

        if !set.isComplete {
            set.isComplete = true
            set.completedAt = event.completedAt
            set.restSeconds = max(event.restSeconds, 0)
            _ = registerPRIfNeeded(
                exercise: session.exercises[exerciseIndex].exercise,
                set: set,
                sessionID: session.id
            )
        }

        session.exercises[exerciseIndex].sets[setIndex] = set
        activeSession = session
        activeExerciseIndex = exerciseIndex
        restEndsAt = set.restSeconds > 0
            ? event.completedAt.addingTimeInterval(TimeInterval(set.restSeconds))
            : nil
        persist()
        return true
    }

    func applyCoachResponse(_ response: CoachAPIResponse, profile: UserProfileSnapshot) {
        coachInsight = response.insight
        guard !response.plan.isEmpty else {
            persist()
            return
        }

        guard let converted = validatedCoachPlan(response.plan, profile: profile) else {
            coachInsight = "The AI proposal exceeded a programming guardrail, so your validated local plan stayed active."
            persist()
            return
        }

        let weeklySets = converted.flatMap(\.exercises).reduce(into: [MuscleGroup: Int]()) { totals, item in
            totals[item.exercise.muscle, default: 0] += item.sets
        }
        weeklyPlan = converted
        if var summary = programSummary {
            summary.generatedAt = Date()
            summary.weeklySetsByMuscle = weeklySets
            summary.rationale = "Coaching proposal validated against your deterministic equipment, movement-limit, coverage, duration, volume, RIR, and load-change guardrails."
            programSummary = summary
        }
        persist()
    }

    func stageCoachResponse(_ response: CoachAPIResponse, profile: UserProfileSnapshot) {
        coachInsight = response.insight
        guard !response.plan.isEmpty else {
            pendingCoachProposal = nil
            persist()
            return
        }
        guard validatedCoachPlan(response.plan, profile: profile) != nil else {
            pendingCoachProposal = nil
            coachInsight = "The AI proposal exceeded a programming guardrail, so your validated local plan stayed active."
            coachMessages.append(
                CoachMessage(
                    role: .coach,
                    text: "I kept your current program because that proposal failed one or more local checks for schedule, exercise access, movement limits, coverage, duration, effort, volume, or load change."
                )
            )
            persist()
            return
        }
        pendingCoachProposal = response
        persist()
    }

    func applyPendingCoachProposal(profile: UserProfileSnapshot) {
        guard let pendingCoachProposal else { return }
        self.pendingCoachProposal = nil
        applyCoachResponse(pendingCoachProposal, profile: profile)
    }

    func discardPendingCoachProposal() {
        pendingCoachProposal = nil
    }

    private func validatedCoachPlan(
        _ proposedDays: [CoachPlanDay],
        profile: UserProfileSnapshot
    ) -> [WorkoutPrescription]? {
        guard proposedDays.count == profile.sessionsPerWeek else { return nil }
        let dates = scheduledDates(for: profile)
        var converted: [WorkoutPrescription] = []

        for (dayIndex, day) in proposedDays.enumerated() {
            guard (3...8).contains(day.exercises.count) else { return nil }
            var seenExerciseIDs = Set<String>()
            var items: [ExercisePrescription] = []

            for update in day.exercises {
                guard seenExerciseIDs.insert(update.exerciseID).inserted,
                      let exercise = ExerciseCatalog.byID[update.exerciseID],
                      ExerciseCatalog.isAvailable(exercise, equipment: profile.equipment),
                      ExerciseCatalog.isPermitted(exercise, constraints: profile.constraints),
                      (1...4).contains(update.sets),
                      (1...30).contains(update.repMin),
                      update.repMax >= update.repMin,
                      update.repMax <= (profile.goal == .muscle ? 20 : 15),
                      (60...300).contains(update.restSeconds),
                      let targetRIR = update.targetRIR,
                      (1...4).contains(targetRIR),
                      update.targetWeightKG.isFinite,
                      update.targetWeightKG >= 0
                else { return nil }

                let reference = weeklyPlan[safe: dayIndex]?
                    .exercises
                    .first(where: { $0.exercise.id == exercise.id })?
                    .targetWeightKG ?? 0
                if reference > 0 {
                    guard update.targetWeightKG >= reference * 0.90,
                          update.targetWeightKG <= reference * 1.10
                    else { return nil }
                } else {
                    guard update.targetWeightKG == 0 else { return nil }
                }

                items.append(
                    ExercisePrescription(
                        exercise: exercise,
                        sets: update.sets,
                        repMin: update.repMin,
                        repMax: update.repMax,
                        targetWeightKG: update.targetWeightKG,
                        restSeconds: update.restSeconds,
                        targetRIR: targetRIR,
                        loadSource: reference > 0 ? "Validated proposal" : "Calibration required",
                        decisionNote: "Passed local equipment, movement-limit, duration, effort, set-count, and ±10% load-change guards.",
                        measurementSystem: profile.measurementSystem.rawValue,
                        incrementKG: ExerciseCatalog.incrementKG(
                            for: exercise,
                            measurementSystem: profile.measurementSystem
                        ),
                        tracksNumericLoad: ExerciseCatalog.usesNumericLoad(exercise)
                    )
                )
            }

            let actualMinutes = estimatedMinutes(for: items)
            guard actualMinutes <= profile.sessionMinutes else { return nil }
            let focus = items.reduce(into: [MuscleGroup]()) { result, item in
                if !result.contains(item.exercise.muscle) { result.append(item.exercise.muscle) }
            }
            converted.append(
                WorkoutPrescription(
                    title: String(day.title.prefix(60)).uppercased(),
                    subtitle: String(day.subtitle.prefix(100)),
                    scheduledDate: dates[safe: dayIndex] ?? Date(),
                    estimatedMinutes: actualMinutes,
                    focus: focus,
                    exercises: items,
                    isAIEnhanced: true,
                    rationale: String(day.rationale.prefix(240))
                )
            )
        }

        let weeklySets = converted.flatMap(\.exercises).reduce(into: [MuscleGroup: Int]()) { totals, item in
            totals[item.exercise.muscle, default: 0] += item.sets
        }
        let minimumMajorGroupSets = min(max(profile.sessionsPerWeek * 2, 4), 6)
        let coversMajorGroups = [MuscleGroup.chest, .back, .legs].allSatisfy {
            weeklySets[$0, default: 0] >= minimumMajorGroupSets
        }
        guard coversMajorGroups, weeklySets.values.allSatisfy({ (1...20).contains($0) }) else {
            return nil
        }
        return converted
    }

    func deleteSession(_ session: WorkoutSession) {
        completedWorkouts.removeAll { $0.id == session.id }
        personalRecords.removeAll { $0.sessionID == session.id }
        persist()
    }

    func volumePoints(days: Int = 7) -> [VolumePoint] {
        let today = calendar.startOfDay(for: Date())
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let volume = completedWorkouts
                .filter { calendar.isDate($0.startedAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.volume }
            return VolumePoint(date: date, volumeKG: volume)
        }
    }

    func recovery(for muscle: MuscleGroup) -> Double {
        guard let mostRecent = completedWorkouts
            .filter({ $0.focus.contains(muscle) })
            .map(\.startedAt)
            .max() else { return 1 }
        let hours = Date().timeIntervalSince(mostRecent) / 3_600
        return min(max(hours / (muscle == .legs ? 72 : 48), 0.12), 1)
    }

    private func mutateSet(exerciseIndex: Int, setIndex: Int, mutation: (inout WorkoutSetLog) -> Void) {
        guard var session = activeSession,
              session.exercises.indices.contains(exerciseIndex),
              session.exercises[exerciseIndex].sets.indices.contains(setIndex) else { return }
        mutation(&session.exercises[exerciseIndex].sets[setIndex])
        activeSession = session
        persist()
    }

    private func registerPRIfNeeded(exercise: ExerciseDefinition, set: WorkoutSetLog, sessionID: UUID) -> Bool {
        guard set.weightKG > 0, set.reps > 0 else { return false }
        let achievedAt = Date()
        var achievedPR = false

        let currentWeightBest = personalRecords
            .filter { $0.exerciseID == exercise.id && $0.metric == .weight }
            .map(\.valueKG)
            .max() ?? 0
        if set.weightKG > currentWeightBest {
            personalRecords.insert(
                PersonalRecord(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    metric: .weight,
                    valueKG: set.weightKG,
                    reps: set.reps,
                    achievedAt: achievedAt,
                    sessionID: sessionID
                ),
                at: 0
            )
            achievedPR = true
        }

        let estimatedOneRepMax = set.weightKG * (1 + Double(min(set.reps, 12)) / 30)
        let currentEstimatedBest = personalRecords
            .filter { $0.exerciseID == exercise.id && $0.metric == .estimatedOneRepMax }
            .map(\.valueKG)
            .max() ?? 0
        if estimatedOneRepMax > currentEstimatedBest {
            personalRecords.insert(
                PersonalRecord(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    metric: .estimatedOneRepMax,
                    valueKG: estimatedOneRepMax,
                    reps: set.reps,
                    achievedAt: achievedAt,
                    sessionID: sessionID
                ),
                at: 0
            )
            achievedPR = true
        }
        return achievedPR
    }

    private func buildPlan(for profile: UserProfileSnapshot) -> [WorkoutPrescription] {
        let blueprints = Self.blueprints(for: profile)
        let dates = scheduledDates(for: profile)
        var plan: [WorkoutPrescription] = []

        for (dayIndex, blueprint) in blueprints.prefix(profile.sessionsPerWeek).enumerated() {
            var usedExerciseIDs = Set<String>()
            var programmed: [(item: ExercisePrescription, role: ExerciseRole)] = []

            for slot in blueprint.slots {
                guard let exercise = selectExercise(
                    pattern: slot.pattern,
                    profile: profile,
                    excluding: usedExerciseIDs
                ) else { continue }
                usedExerciseIDs.insert(exercise.id)
                programmed.append((makePrescription(for: exercise, role: slot.role, profile: profile), slot.role))
            }

            if programmed.count < 3 {
                for exercise in ExerciseCatalog.all where programmed.count < 3 {
                    guard !usedExerciseIDs.contains(exercise.id),
                          ExerciseCatalog.isAvailable(exercise, equipment: profile.equipment),
                          ExerciseCatalog.isPermitted(exercise, constraints: profile.constraints)
                    else { continue }
                    usedExerciseIDs.insert(exercise.id)
                    let role: ExerciseRole = exercise.muscle == .core ? .core : .accessory
                    programmed.append((makePrescription(for: exercise, role: role, profile: profile), role))
                }
            }

            fit(programmed: &programmed, within: profile.sessionMinutes)
            let exercises = programmed.map(\.item)
            let focus = exercises.reduce(into: [MuscleGroup]()) { result, item in
                guard !result.contains(item.exercise.muscle) else { return }
                result.append(item.exercise.muscle)
            }
            let calibrationCount = exercises.filter { $0.targetWeightKG == 0 && ExerciseCatalog.usesNumericLoad($0.exercise) }.count
            let rationale = calibrationCount > 0
                ? "Selected for your goal, available equipment, movement limits, and schedule. \(calibrationCount) movement\(calibrationCount == 1 ? "" : "s") will calibrate from a comfortable set at the shown RIR."
                : "Selected from movements you can perform with your equipment, then loaded from recent sets or your onboarding baselines."

            plan.append(
                WorkoutPrescription(
                    title: blueprint.title,
                    subtitle: blueprint.subtitle,
                    scheduledDate: dates[safe: dayIndex] ?? Date(),
                    estimatedMinutes: estimatedMinutes(for: exercises),
                    focus: focus,
                    exercises: exercises,
                    rationale: rationale
                )
            )
        }

        let setTotals = plan.flatMap(\.exercises).reduce(into: [MuscleGroup: Int]()) { totals, item in
            totals[item.exercise.muscle, default: 0] += item.sets
        }
        let defaultRIR = targetRIR(for: profile)
        let blockWeek: Int
        if let previousSummary = programSummary,
           let previousWeek = calendar.dateInterval(of: .weekOfYear, for: previousSummary.generatedAt)?.start,
           let currentWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start {
            let elapsedWeeks = max(calendar.dateComponents([.weekOfYear], from: previousWeek, to: currentWeek).weekOfYear ?? 0, 0)
            blockWeek = ((previousSummary.weekNumber - 1 + elapsedWeeks) % 4) + 1
        } else {
            blockWeek = 1
        }
        programSummary = ProgramSummary(
            generatedAt: Date(),
            weekNumber: blockWeek,
            blockLengthWeeks: 4,
            splitName: Self.splitName(for: profile.sessionsPerWeek),
            goal: profile.goal,
            targetRIR: defaultRIR,
            weeklySetsByMuscle: setTotals,
            rationale: "\(Self.splitName(for: profile.sessionsPerWeek)) distributes your work across \(profile.sessionsPerWeek) available days. Exercises are filtered by equipment and every movement limit you selected.",
            progressionRule: "Reach the top of the rep range near target RIR for two exposures to earn the smallest sensible load increase. Missed reps or unexpectedly hard sets hold or reduce load.",
            evidenceNote: "Built from the 2026 ACSM resistance-training position stand: progressive training, major muscle groups, goal-specific loading, multiple sets, and no required failure."
        )
        return plan
    }

    private func makePrescription(
        for exercise: ExerciseDefinition,
        role: ExerciseRole,
        profile: UserProfileSnapshot
    ) -> ExercisePrescription {
        var parameters = prescriptionParameters(role: role, profile: profile)
        if !ExerciseCatalog.usesNumericLoad(exercise),
           let latest = recentExerciseLogs(for: exercise.id).first,
           let latestSet = latest.sets.first {
            parameters.sets = latest.sets.count
            parameters.repMin = latestSet.targetRepMin
            parameters.repMax = latestSet.targetRepMax
            switch progressionDirection(from: Array(recentExerciseLogs(for: exercise.id).prefix(2))) {
            case .increase where parameters.repMax < 20:
                parameters.repMin += 1
                parameters.repMax += 1
            case .increase where parameters.sets < 4:
                parameters.sets += 1
            case .reduce:
                parameters.repMin = max(parameters.repMin - 2, 1)
                parameters.repMax = max(parameters.repMax - 2, parameters.repMin)
            default:
                break
            }
        }
        let load = loadRecommendation(
            for: exercise,
            repMin: parameters.repMin,
            repMax: parameters.repMax,
            targetRIR: parameters.rir,
            profile: profile,
            role: role
        )
        return ExercisePrescription(
            exercise: exercise,
            sets: parameters.sets,
            repMin: parameters.repMin,
            repMax: parameters.repMax,
            targetWeightKG: load.weightKG,
            restSeconds: parameters.restSeconds,
            targetRIR: parameters.rir,
            loadSource: load.source,
            decisionNote: load.note,
            measurementSystem: profile.measurementSystem.rawValue,
            incrementKG: ExerciseCatalog.incrementKG(
                for: exercise,
                measurementSystem: profile.measurementSystem
            ),
            tracksNumericLoad: ExerciseCatalog.usesNumericLoad(exercise)
        )
    }

    private func prescriptionParameters(
        role: ExerciseRole,
        profile: UserProfileSnapshot
    ) -> (sets: Int, repMin: Int, repMax: Int, restSeconds: Int, rir: Int) {
        let rir = targetRIR(for: profile)
        switch profile.goal {
        case .strength:
            switch role {
            case .primary: return (3, 3, 6, 180, max(rir, 2))
            case .secondary: return (3, 6, 10, 150, rir)
            case .accessory: return (profile.experience == .beginner ? 2 : 3, 8, 15, 90, rir)
            case .core: return (2, 8, 12, 75, rir)
            }
        case .muscle:
            switch role {
            case .primary: return (3, 6, 10, 120, rir)
            case .secondary: return (3, 8, 12, 120, rir)
            case .accessory: return (3, 10, 15, 90, rir)
            case .core: return (2, 10, 15, 75, rir)
            }
        case .generalFitness:
            switch role {
            case .primary: return (3, 6, 12, 120, rir)
            case .secondary: return (2, 8, 12, 105, rir)
            case .accessory: return (2, 10, 15, 75, rir)
            case .core: return (2, 8, 15, 60, rir)
            }
        case .athleticPerformance:
            switch role {
            case .primary: return (3, 3, 5, 180, max(rir, 3))
            case .secondary: return (3, 5, 8, 150, rir)
            case .accessory: return (2, 8, 12, 90, rir)
            case .core: return (2, 8, 12, 75, rir)
            }
        }
    }

    private func targetRIR(for profile: UserProfileSnapshot) -> Int {
        if profile.trainingAgeMonths < 6 || profile.experience == .beginner { return 3 }
        if profile.recoveryRating <= 2 { return 3 }
        return 2
    }

    private func loadRecommendation(
        for exercise: ExerciseDefinition,
        repMin: Int,
        repMax: Int,
        targetRIR: Int,
        profile: UserProfileSnapshot,
        role: ExerciseRole
    ) -> LoadRecommendation {
        if !ExerciseCatalog.usesNumericLoad(exercise) {
            return LoadRecommendation(
                weightKG: 0,
                source: "Rep-based resistance",
                note: "Use controlled range of motion or band tension and finish near \(targetRIR) RIR."
            )
        }

        let recent = recentExerciseLogs(for: exercise.id)
        if let latest = recent.first,
           let current = latest.sets.filter({ $0.isComplete && $0.weightKG > 0 }).map(\.weightKG).max() {
            let direction = progressionDirection(from: Array(recent.prefix(2)))
            let increment = ExerciseCatalog.incrementKG(
                for: exercise,
                measurementSystem: profile.measurementSystem
            )
            let next: Double
            let note: String
            switch direction {
            case .increase where recent.count >= 2:
                let candidate = current + increment
                if current > 0, (candidate - current) / current <= 0.10 {
                    next = candidate
                    note = "Two top-range exposures at the prescribed effort earned the smallest available increase."
                } else {
                    next = current
                    note = "Performance earned progression, but the next equipment jump is too large; add reps before load."
                }
            case .reduce:
                next = conservativeReduction(from: current, increment: increment)
                note = next < current
                    ? "Recent sets missed the rep floor or were harder than prescribed, so load is reduced conservatively."
                    : "Recent sets were harder than prescribed, but the smallest available decrement exceeds the 10% guardrail. Hold load and rebuild clean reps."
            default:
                next = current
                note = "Load is held until every working set reaches the progression target at the planned effort."
            }
            return LoadRecommendation(
                weightKG: max(next, 0),
                source: "Recent working sets",
                note: note
            )
        }

        if let baseline = profile.baselines.first(where: { $0.exerciseID == exercise.id }), baseline.weightKG > 0 {
            let midpoint = Double(repMin + repMax) / 2
            let predicted: Double
            if profile.goal == .athleticPerformance, role == .primary {
                predicted = baseline.estimatedOneRepMaxKG * 0.60
            } else {
                predicted = baseline.estimatedOneRepMaxKG / (1 + (midpoint + Double(targetRIR)) / 30) * 0.92
            }
            let increment = ExerciseCatalog.incrementKG(
                for: exercise,
                measurementSystem: profile.measurementSystem
            )
            return LoadRecommendation(
                weightKG: max(roundedDown(predicted, increment: increment), 0),
                source: "Onboarding working set",
                note: "A conservative starting load derived from your recent load × reps × RIR; adjust if today feels different."
            )
        }

        return LoadRecommendation(
            weightKG: 0,
            source: "Calibration required",
            note: "Choose a comfortable first-session load that leaves about \(targetRIR) good reps. That set becomes your baseline."
        )
    }

    private func recentExerciseLogs(for exerciseID: String) -> [SessionExercise] {
        let cutoff = calendar.date(byAdding: .day, value: -42, to: Date()) ?? .distantPast
        var seenTrainingDays = Set<Date>()
        return completedWorkouts
            .filter { $0.startedAt >= cutoff }
            .sorted { $0.startedAt > $1.startedAt }
            .compactMap { session in
                guard let exposure = session.exercises.first(where: { $0.exercise.id == exerciseID }) else {
                    return nil
                }
                let trainingDay = calendar.startOfDay(for: session.startedAt)
                guard seenTrainingDays.insert(trainingDay).inserted else { return nil }
                return exposure
            }
        }

    private func progressionDirection(from exposures: [SessionExercise]) -> AdaptationDirection {
        guard let latest = exposures.first else { return .calibrate }
        let latestCompleted = latest.sets.filter(\.isComplete)
        guard !latestCompleted.isEmpty else { return .hold }

        let missed = latestCompleted.filter {
            guard let reportedRIR = $0.reportedRIR else { return false }
            return $0.reps < $0.targetRepMin || reportedRIR < max($0.effectiveTargetRIR - 1, 0)
        }.count
        if missed >= max(2, latestCompleted.count / 2) { return .reduce }

        guard exposures.count >= 2 else { return .hold }
        let bothSuccessful = exposures.prefix(2).allSatisfy { exercise in
            !exercise.sets.isEmpty && exercise.sets.allSatisfy { set in
                guard let reportedRIR = set.reportedRIR else { return false }
                return set.isComplete
                    && set.reps >= set.targetRepMax
                    && reportedRIR >= max(set.effectiveTargetRIR - 1, 0)
            }
        }
        return bothSuccessful ? .increase : .hold
    }

    private func updatePrescriptionAfter(_ session: WorkoutSession) {
        let newDecisions = session.exercises.compactMap { log -> AdaptationDecision? in
            if !ExerciseCatalog.usesNumericLoad(log.exercise) {
                let direction = progressionDirection(from: Array(recentExerciseLogs(for: log.exercise.id).prefix(2)))
                let reason: String
                switch direction {
                case .increase:
                    reason = "Two complete top-range exposures earned a rep, set, band-tension, or variation progression next week."
                case .reduce:
                    reason = "Recent reps or effort were below target, so next week uses an easier rep target or variation."
                case .hold:
                    reason = "Repeat this rep-based prescription until two complete exposures land near target effort."
                case .calibrate:
                    reason = "Log reps and RIR to establish a rep-based baseline."
                }
                return AdaptationDecision(
                    exerciseID: log.exercise.id,
                    exerciseName: log.exercise.name,
                    direction: direction,
                    previousLoadKG: 0,
                    nextLoadKG: 0,
                    reason: reason
                )
            }
            guard let current = log.sets.filter({ $0.isComplete && $0.weightKG > 0 }).map(\.weightKG).max() else {
                return AdaptationDecision(
                    exerciseID: log.exercise.id,
                    exerciseName: log.exercise.name,
                    direction: .calibrate,
                    previousLoadKG: 0,
                    nextLoadKG: 0,
                    reason: "No weighted working set was logged; the next exposure remains a calibration."
                )
            }
            var direction = progressionDirection(from: Array(recentExerciseLogs(for: log.exercise.id).prefix(2)))
            let increment = prescribedIncrementKG(for: log.exercise)
            var next = current
            var reason = "Hold load until two complete top-range exposures land near target RIR."
            if direction == .increase {
                let candidate = current + increment
                if (candidate - current) / current <= 0.10 {
                    next = candidate
                    reason = "Two successful top-range exposures earned the smallest sensible load increase next week."
                } else {
                    direction = .hold
                    reason = "Top-range reps were successful, but the next equipment jump exceeds the 10% load-change guardrail."
                }
            } else if direction == .reduce {
                next = conservativeReduction(from: current, increment: increment)
                if next < current {
                    reason = "Multiple missed or unexpectedly hard sets trigger a conservative load reduction next week."
                } else {
                    direction = .hold
                    reason = "A reduction was indicated, but the smallest equipment decrement exceeds 10%; hold load and rebuild clean reps."
                }
            }
            return AdaptationDecision(
                exerciseID: log.exercise.id,
                exerciseName: log.exercise.name,
                direction: direction,
                previousLoadKG: current,
                nextLoadKG: next,
                reason: reason
            )
        }
        adaptationDecisions.insert(contentsOf: newDecisions, at: 0)
        adaptationDecisions = Array(adaptationDecisions.prefix(80))
    }

    private func prescribedIncrementKG(for exercise: ExerciseDefinition) -> Double {
        weeklyPlan
            .lazy
            .flatMap(\.exercises)
            .first(where: { $0.exercise.id == exercise.id })?
            .incrementKG
            ?? ExerciseCatalog.metadata(for: exercise).incrementKG
    }

    private func updateLocalInsight(after session: WorkoutSession) {
        let completed = session.completedSetCount
        let total = max(session.totalSetCount, 1)
        let increases = adaptationDecisions.prefix(session.exercises.count).filter { $0.direction == .increase }.count
        let reductions = adaptationDecisions.prefix(session.exercises.count).filter { $0.direction == .reduce }.count
        if increases > 0 {
            coachInsight = "\(increases) movement\(increases == 1 ? "" : "s") earned next-week progression after two top-range exposures at target effort."
        } else if reductions > 0 {
            coachInsight = "I flagged \(reductions) movement\(reductions == 1 ? "" : "s") for a conservative next-week reduction after missed or unexpectedly hard sets."
        } else {
            coachInsight = "You logged \(completed) of \(total) sets. Loads stay stable until the full double-progression standard is met."
        }
    }

    private func selectExercise(
        pattern: MovementPattern,
        profile: UserProfileSnapshot,
        excluding: Set<String>
    ) -> ExerciseDefinition? {
        let recentIDs = Set(completedWorkouts.prefix(12).flatMap(\.exercises).map { $0.exercise.id })
        let baselineIDs = Set(profile.baselines.map(\.exerciseID))
        return ExerciseCatalog.all
            .filter { exercise in
                !excluding.contains(exercise.id)
                    && ExerciseCatalog.metadata(for: exercise).pattern == pattern
                    && ExerciseCatalog.isAvailable(exercise, equipment: profile.equipment)
                    && ExerciseCatalog.isPermitted(exercise, constraints: profile.constraints)
            }
            .enumerated()
            .min { lhs, rhs in
                let lhsScore = (baselineIDs.contains(lhs.element.id) ? 0 : (recentIDs.contains(lhs.element.id) ? 1 : 2), lhs.offset)
                let rhsScore = (baselineIDs.contains(rhs.element.id) ? 0 : (recentIDs.contains(rhs.element.id) ? 1 : 2), rhs.offset)
                return lhsScore < rhsScore
            }?
            .element
    }

    private func fit(
        programmed: inout [(item: ExercisePrescription, role: ExerciseRole)],
        within minutes: Int
    ) {
        while estimatedMinutes(for: programmed.map(\.item)) > minutes {
            if let index = programmed.indices.reversed().first(where: {
                programmed[$0].role != .primary && programmed[$0].item.sets > 2
            }) {
                programmed[index].item.sets -= 1
            } else if programmed.count > 3 {
                programmed.removeLast()
            } else {
                break
            }
        }
    }

    private func estimatedMinutes(for exercises: [ExercisePrescription]) -> Int {
        let workingSeconds = exercises.reduce(5 * 60) { total, item in
            total + item.sets * 45 + max(item.sets - 1, 0) * item.restSeconds + 60
        }
        return max(Int(ceil(Double(workingSeconds) / 60)), 20)
    }

    private func scheduledDates(for profile: UserProfileSnapshot) -> [Date] {
        var selected = profile.preferredWeekdays.sorted()
        let defaults = Self.defaultWeekdays(for: profile.sessionsPerWeek)
        for day in defaults where selected.count < profile.sessionsPerWeek && !selected.contains(day) {
            selected.append(day)
        }
        selected = Array(selected.sorted().prefix(profile.sessionsPerWeek))
        let today = calendar.startOfDay(for: Date())
        let appleWeekday = calendar.component(.weekday, from: today)
        let currentISOWeekday = appleWeekday == 1 ? 7 : appleWeekday - 1
        return selected.compactMap { isoWeekday in
            let daysUntil = (isoWeekday - currentISOWeekday + 7) % 7
            guard let date = calendar.date(byAdding: .day, value: daysUntil, to: today) else { return nil }
            return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        }
        .sorted()
    }

    private func roundedDown(_ kilograms: Double, increment: Double) -> Double {
        guard increment > 0 else { return max(kilograms, 0) }
        return floor(max(kilograms, 0) / increment) * increment
    }

    private func conservativeReduction(from current: Double, increment: Double) -> Double {
        guard current > 0, increment > 0 else { return max(current, 0) }
        let candidate = roundedDown(current * 0.95, increment: increment)
        guard candidate > 0, candidate < current, (current - candidate) / current <= 0.10 else {
            return current
        }
        return candidate
    }

    private func persist() {
        let state = PersistedTrainingState(
            weeklyPlan: weeklyPlan,
            programSummary: programSummary,
            adaptationDecisions: adaptationDecisions,
            completedWorkouts: completedWorkouts,
            activeSession: activeSession,
            activeExerciseIndex: activeExerciseIndex,
            restEndsAt: restEndsAt,
            personalRecords: personalRecords,
            coachMessages: coachMessages,
            coachInsight: coachInsight,
            planSignature: planSignature
        )
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: persistenceURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let state = try? JSONDecoder().decode(PersistedTrainingState.self, from: data) else { return }
        weeklyPlan = state.weeklyPlan
        programSummary = state.programSummary
        adaptationDecisions = state.adaptationDecisions ?? []
        completedWorkouts = state.completedWorkouts
        activeSession = state.activeSession
        activeExerciseIndex = state.activeExerciseIndex
        restEndsAt = state.restEndsAt
        personalRecords = state.personalRecords
        coachMessages = state.coachMessages
        coachInsight = state.coachInsight
        planSignature = state.planSignature
    }

    #if DEBUG
    /// Store imagery needs to demonstrate the product after it has learned from
    /// real sessions. This fixture is compiled only into debug builds and is
    /// enabled only by the dedicated screenshot UI test.
    private func seedAppStoreScreenshotHistoryIfNeeded() {
        guard ProcessInfo.processInfo.environment["FITNESS_BUDDY_APP_STORE_SCREENSHOTS"] == "1",
              completedWorkouts.isEmpty else { return }

        func fixtureDate(daysAgo: Int) -> Date {
            let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: Date())) ?? Date()
            return calendar.date(bySettingHour: 1, minute: 0, second: 0, of: day) ?? day
        }

        func fixtureExercise(
            id: String,
            weightKG: Double,
            reps: Int,
            completedAt: Date
        ) -> SessionExercise? {
            guard let exercise = ExerciseCatalog.byID[id] else { return nil }
            return SessionExercise(
                exercise: exercise,
                cue: exercise.cue,
                sets: (1...3).map { setNumber in
                    WorkoutSetLog(
                        setNumber: setNumber,
                        targetRepMin: reps,
                        targetRepMax: reps + 2,
                        weightKG: weightKG,
                        reps: reps,
                        isComplete: true,
                        completedAt: completedAt,
                        restSeconds: 120,
                        targetRIR: 2,
                        reportedRIR: setNumber == 3 ? 1 : 2
                    )
                },
                loadSource: "Learned from your recent sets",
                decisionNote: "Held inside the validated progression range."
            )
        }

        func fixtureSession(
            title: String,
            daysAgo: Int,
            templates: [(String, Double, Int)]
        ) -> WorkoutSession {
            let startedAt = fixtureDate(daysAgo: daysAgo)
            let endedAt = startedAt.addingTimeInterval(52 * 60)
            let exercises = templates.compactMap { template in
                fixtureExercise(
                    id: template.0,
                    weightKG: template.1,
                    reps: template.2,
                    completedAt: endedAt
                )
            }
            let focus = exercises.reduce(into: [MuscleGroup]()) { result, item in
                if !result.contains(item.exercise.muscle) {
                    result.append(item.exercise.muscle)
                }
            }
            return WorkoutSession(
                title: title,
                focus: focus,
                startedAt: startedAt,
                endedAt: endedAt,
                exercises: exercises
            )
        }

        let upperA = fixtureSession(
            title: "UPPER / A",
            daysAgo: 6,
            templates: [
                ("barbell-bench", 59, 8),
                ("barbell-row", 47.5, 9),
                ("shoulder-press", 18, 10),
            ]
        )
        let lowerA = fixtureSession(
            title: "LOWER / A",
            daysAgo: 4,
            templates: [
                ("back-squat", 79.5, 7),
                ("romanian-deadlift", 68, 8),
                ("calf-raise", 45, 12),
            ]
        )
        let upperB = fixtureSession(
            title: "UPPER / B",
            daysAgo: 2,
            templates: [
                ("barbell-bench", 61.2, 8),
                ("lat-pulldown", 49.9, 10),
                ("db-curl", 12, 12),
            ]
        )
        let lowerB = fixtureSession(
            title: "LOWER / B",
            daysAgo: 1,
            templates: [
                ("back-squat", 83.9, 6),
                ("romanian-deadlift", 72.6, 8),
                ("walking-lunge", 18, 10),
            ]
        )

        completedWorkouts = [lowerB, upperB, lowerA, upperA]
        personalRecords = [
            PersonalRecord(
                exerciseID: "back-squat",
                exerciseName: "Barbell Back Squat",
                metric: .estimatedOneRepMax,
                valueKG: 100.7,
                reps: 6,
                achievedAt: lowerB.endedAt ?? lowerB.startedAt,
                sessionID: lowerB.id
            ),
            PersonalRecord(
                exerciseID: "barbell-bench",
                exerciseName: "Barbell Bench Press",
                metric: .weight,
                valueKG: 61.2,
                reps: 8,
                achievedAt: upperB.endedAt ?? upperB.startedAt,
                sessionID: upperB.id
            ),
            PersonalRecord(
                exerciseID: "romanian-deadlift",
                exerciseName: "Romanian Deadlift",
                metric: .weight,
                valueKG: 72.6,
                reps: 8,
                achievedAt: lowerB.endedAt ?? lowerB.startedAt,
                sessionID: lowerB.id
            ),
        ]
        adaptationDecisions = [
            AdaptationDecision(
                exerciseID: "barbell-bench",
                exerciseName: "Barbell Bench Press",
                direction: .increase,
                previousLoadKG: 59,
                nextLoadKG: 61.2,
                reason: "Two strong exposures reached the top of the rep range at target effort.",
                createdAt: upperB.endedAt ?? upperB.startedAt
            ),
        ]
        coachInsight = "Your recent sessions landed at target effort. Upper-body loads are ready for a measured increase."
        coachMessages = [
            CoachMessage(
                role: .coach,
                text: "Your last four sessions are consistent. I moved bench press up one increment and kept lower-body volume stable."
            ),
        ]
        persist()
    }
    #endif

    private func migrateLegacyHistoryIfNeeded() {
        guard completedWorkouts.isEmpty,
              let data = UserDefaults.standard.data(forKey: "completedWorkouts"),
              let legacy = try? JSONDecoder().decode([LegacyCompletedWorkout].self, from: data) else { return }
        completedWorkouts = legacy.map { item in
            WorkoutSession(
                title: item.bodyParts.isEmpty ? "Imported workout" : item.bodyParts.joined(separator: " + "),
                focus: item.bodyParts.compactMap(MuscleGroup.init(rawValue:)),
                startedAt: item.date,
                endedAt: item.date,
                exercises: [],
                isLegacySummary: true
            )
        }.sorted { $0.startedAt > $1.startedAt }
        persist()
    }

    private enum ExerciseRole {
        case primary
        case secondary
        case accessory
        case core
    }

    private struct MovementSlot {
        let pattern: MovementPattern
        let role: ExerciseRole
    }

    private struct DayBlueprint {
        let title: String
        let subtitle: String
        let slots: [MovementSlot]
    }

    private struct LoadRecommendation {
        let weightKG: Double
        let source: String
        let note: String
    }

    private static func blueprints(for profile: UserProfileSnapshot) -> [DayBlueprint] {
        let fullA = DayBlueprint(
            title: "FULL / FOUNDATION",
            subtitle: "Squat, push, pull, hinge",
            slots: [
                MovementSlot(pattern: .squat, role: .primary),
                MovementSlot(pattern: .horizontalPush, role: .secondary),
                MovementSlot(pattern: .horizontalPull, role: .secondary),
                MovementSlot(pattern: .hinge, role: .accessory),
                MovementSlot(pattern: .verticalPull, role: .accessory),
                MovementSlot(pattern: .coreAntiExtension, role: .core),
            ]
        )
        let fullB = DayBlueprint(
            title: "FULL / BUILD",
            subtitle: "Hinge, press, pull, single-leg",
            slots: [
                MovementSlot(pattern: .hinge, role: .primary),
                MovementSlot(pattern: .verticalPush, role: .secondary),
                MovementSlot(pattern: .verticalPull, role: .secondary),
                MovementSlot(pattern: .singleLeg, role: .accessory),
                MovementSlot(pattern: .horizontalPush, role: .accessory),
                MovementSlot(pattern: .coreAntiRotation, role: .core),
            ]
        )
        let fullC = DayBlueprint(
            title: "FULL / PROGRESS",
            subtitle: "Repeat the skills that drive progress",
            slots: [
                MovementSlot(pattern: .squat, role: .primary),
                MovementSlot(pattern: .horizontalPush, role: .secondary),
                MovementSlot(pattern: .horizontalPull, role: .secondary),
                MovementSlot(pattern: .hinge, role: .accessory),
                MovementSlot(pattern: .lateralRaise, role: .accessory),
                MovementSlot(pattern: .coreAntiExtension, role: .core),
            ]
        )
        let upperA = DayBlueprint(
            title: "UPPER / A",
            subtitle: "Horizontal strength and balanced volume",
            slots: [
                MovementSlot(pattern: .horizontalPush, role: .primary),
                MovementSlot(pattern: .horizontalPull, role: .primary),
                MovementSlot(pattern: .verticalPush, role: .secondary),
                MovementSlot(pattern: .verticalPull, role: .secondary),
                MovementSlot(pattern: .armFlexion, role: .accessory),
                MovementSlot(pattern: .armExtension, role: .accessory),
            ]
        )
        let lowerA = DayBlueprint(
            title: "LOWER / A",
            subtitle: "Knee-dominant strength and trunk control",
            slots: [
                MovementSlot(pattern: .squat, role: .primary),
                MovementSlot(pattern: .hinge, role: .secondary),
                MovementSlot(pattern: .singleLeg, role: .accessory),
                MovementSlot(pattern: .calves, role: .accessory),
                MovementSlot(pattern: .coreAntiExtension, role: .core),
            ]
        )
        let upperB = DayBlueprint(
            title: "UPPER / B",
            subtitle: "Vertical strength and shoulder balance",
            slots: [
                MovementSlot(pattern: .verticalPull, role: .primary),
                MovementSlot(pattern: .verticalPush, role: .primary),
                MovementSlot(pattern: .horizontalPush, role: .secondary),
                MovementSlot(pattern: .horizontalPull, role: .secondary),
                MovementSlot(pattern: .lateralRaise, role: .accessory),
                MovementSlot(pattern: .armFlexion, role: .accessory),
            ]
        )
        let lowerB = DayBlueprint(
            title: "LOWER / B",
            subtitle: "Hip-dominant strength and unilateral work",
            slots: [
                MovementSlot(pattern: .hinge, role: .primary),
                MovementSlot(pattern: .squat, role: .secondary),
                MovementSlot(pattern: .singleLeg, role: .accessory),
                MovementSlot(pattern: .calves, role: .accessory),
                MovementSlot(pattern: .coreAntiRotation, role: .core),
            ]
        )
        let push = DayBlueprint(
            title: "PUSH / SYSTEM",
            subtitle: "Chest, shoulders, triceps",
            slots: [
                MovementSlot(pattern: .horizontalPush, role: .primary),
                MovementSlot(pattern: .verticalPush, role: .secondary),
                MovementSlot(pattern: .horizontalPush, role: .accessory),
                MovementSlot(pattern: .lateralRaise, role: .accessory),
                MovementSlot(pattern: .armExtension, role: .accessory),
            ]
        )
        let pull = DayBlueprint(
            title: "PULL / SYSTEM",
            subtitle: "Back, rear shoulder, biceps",
            slots: [
                MovementSlot(pattern: .verticalPull, role: .primary),
                MovementSlot(pattern: .horizontalPull, role: .secondary),
                MovementSlot(pattern: .horizontalPull, role: .accessory),
                MovementSlot(pattern: .armFlexion, role: .accessory),
                MovementSlot(pattern: .coreAntiExtension, role: .core),
            ]
        )
        let legs = DayBlueprint(
            title: "LEGS / SYSTEM",
            subtitle: "Squat, hinge, unilateral strength",
            slots: [
                MovementSlot(pattern: .squat, role: .primary),
                MovementSlot(pattern: .hinge, role: .secondary),
                MovementSlot(pattern: .singleLeg, role: .accessory),
                MovementSlot(pattern: .calves, role: .accessory),
                MovementSlot(pattern: .coreAntiRotation, role: .core),
            ]
        )

        switch profile.sessionsPerWeek {
        case ...2:
            return [fullA, fullB]
        case 3:
            return profile.experience == .beginner ? [fullA, fullB, fullC] : [upperA, lowerA, fullC]
        case 4:
            return [upperA, lowerA, upperB, lowerB]
        case 5:
            return [upperA, lowerA, fullC, upperB, lowerB]
        default:
            return [push, pull, legs, push, pull, legs]
        }
    }

    private static func splitName(for count: Int) -> String {
        switch count {
        case ...2: "Full body A/B"
        case 3: "Three-day full-body hybrid"
        case 4: "Upper / lower ×2"
        case 5: "Upper / lower + priority"
        default: "Push / pull / legs ×2"
        }
    }

    private static func defaultWeekdays(for count: Int) -> [Int] {
        switch count {
        case ...2: [1, 4]
        case 3: [1, 3, 5]
        case 4: [1, 2, 4, 6]
        case 5: [1, 2, 3, 5, 6]
        default: [1, 2, 3, 4, 5, 6]
        }
    }
}

struct ExerciseProgrammingMetadata: Sendable {
    let pattern: MovementPattern
    let equipment: Set<EquipmentOption>
    let blockedBy: Set<TrainingConstraint>
    let incrementKG: Double
    let tracksNumericLoad: Bool
}

enum ExerciseCatalog {
    static let all: [ExerciseDefinition] = [
        ExerciseDefinition(id: "back-squat", name: "Barbell Back Squat", muscle: .legs, equipment: "Barbell + rack", cue: "Brace first. Sit between your hips and drive the floor away."),
        ExerciseDefinition(id: "goblet-squat", name: "Goblet Squat", muscle: .legs, equipment: "Dumbbell", cue: "Keep the bell close and let your knees track over your toes."),
        ExerciseDefinition(id: "leg-press", name: "Leg Press", muscle: .legs, equipment: "Machine", cue: "Control the bottom and keep your whole foot connected."),
        ExerciseDefinition(id: "bodyweight-squat", name: "Tempo Bodyweight Squat", muscle: .legs, equipment: "Bodyweight", cue: "Use a range you own and stand with steady speed."),
        ExerciseDefinition(id: "trap-bar-deadlift", name: "Trap Bar Deadlift", muscle: .legs, equipment: "Trap bar", cue: "Own the floor, brace, then stand tall without leaning back."),
        ExerciseDefinition(id: "romanian-deadlift", name: "Romanian Deadlift", muscle: .legs, equipment: "Barbell", cue: "Push your hips back and keep the bar close to your legs."),
        ExerciseDefinition(id: "db-romanian-deadlift", name: "Dumbbell Romanian Deadlift", muscle: .legs, equipment: "Dumbbells", cue: "Reach your hips back while the dumbbells track close to your legs."),
        ExerciseDefinition(id: "cable-pull-through", name: "Cable Pull-Through", muscle: .legs, equipment: "Cable", cue: "Let the hips travel back, then finish tall with the glutes."),
        ExerciseDefinition(id: "glute-bridge", name: "Glute Bridge", muscle: .legs, equipment: "Bodyweight", cue: "Keep ribs down and finish through the hips, not the low back."),
        ExerciseDefinition(id: "walking-lunge", name: "Walking Lunge", muscle: .legs, equipment: "Dumbbells", cue: "Take a stable step and lower straight down with control."),
        ExerciseDefinition(id: "reverse-lunge", name: "Reverse Lunge", muscle: .legs, equipment: "Bodyweight", cue: "Step back softly and drive through the whole front foot."),
        ExerciseDefinition(id: "split-squat", name: "Dumbbell Split Squat", muscle: .legs, equipment: "Dumbbells", cue: "Stay tall, lower straight down, and keep the front foot rooted."),
        ExerciseDefinition(id: "calf-raise", name: "Standing Calf Raise", muscle: .legs, equipment: "Machine", cue: "Pause in the stretch, then finish high on the ball of your foot."),
        ExerciseDefinition(id: "single-leg-calf-raise", name: "Single-Leg Calf Raise", muscle: .legs, equipment: "Bodyweight", cue: "Use support for balance and pause at both ends of the rep."),

        ExerciseDefinition(id: "barbell-bench", name: "Barbell Bench Press", muscle: .chest, equipment: "Barbell + rack", cue: "Set your upper back, touch with control, and press toward the rack."),
        ExerciseDefinition(id: "db-bench", name: "Dumbbell Bench Press", muscle: .chest, equipment: "Dumbbells", cue: "Set your shoulders, lower with control, and press up and in."),
        ExerciseDefinition(id: "incline-db-press", name: "Incline Dumbbell Press", muscle: .chest, equipment: "Dumbbells", cue: "Keep ribs stacked and drive your upper arms toward the ceiling."),
        ExerciseDefinition(id: "machine-chest-press", name: "Machine Chest Press", muscle: .chest, equipment: "Machine", cue: "Set the seat for a comfortable shoulder path and press smoothly."),
        ExerciseDefinition(id: "push-up", name: "Push-Up", muscle: .chest, equipment: "Bodyweight", cue: "Move as one unit and finish with the floor far away."),

        ExerciseDefinition(id: "barbell-overhead-press", name: "Barbell Overhead Press", muscle: .shoulders, equipment: "Barbell + rack", cue: "Brace, press close to your face, and finish stacked overhead."),
        ExerciseDefinition(id: "shoulder-press", name: "Seated Dumbbell Press", muscle: .shoulders, equipment: "Dumbbells", cue: "Stack wrists over elbows and finish without arching your back."),
        ExerciseDefinition(id: "machine-shoulder-press", name: "Machine Shoulder Press", muscle: .shoulders, equipment: "Machine", cue: "Choose a pain-free grip and keep the ribs stacked."),
        ExerciseDefinition(id: "pike-push-up", name: "Pike Push-Up", muscle: .shoulders, equipment: "Bodyweight", cue: "Send the crown of your head forward and press the floor away."),

        ExerciseDefinition(id: "barbell-row", name: "Barbell Row", muscle: .back, equipment: "Barbell", cue: "Hold a quiet torso and pull the bar toward your lower ribs."),
        ExerciseDefinition(id: "cable-row", name: "Seated Cable Row", muscle: .back, equipment: "Cable", cue: "Stay tall and finish by moving your elbows behind your torso."),
        ExerciseDefinition(id: "chest-supported-row", name: "Chest-Supported Row", muscle: .back, equipment: "Dumbbells", cue: "Keep your chest planted and sweep your elbows back."),
        ExerciseDefinition(id: "one-arm-db-row", name: "One-Arm Dumbbell Row", muscle: .back, equipment: "Dumbbell", cue: "Keep your torso quiet and pull your elbow toward your hip."),
        ExerciseDefinition(id: "machine-row", name: "Machine Row", muscle: .back, equipment: "Machine", cue: "Stay connected to the pad and finish without shrugging."),
        ExerciseDefinition(id: "band-row", name: "Resistance-Band Row", muscle: .back, equipment: "Band", cue: "Stay tall and separate your hands as your elbows travel back."),
        ExerciseDefinition(id: "prone-w-raise", name: "Prone W Raise", muscle: .back, equipment: "Bodyweight", cue: "Lift lightly, rotate the thumbs up, and keep the neck relaxed."),
        ExerciseDefinition(id: "lat-pulldown", name: "Lat Pulldown", muscle: .back, equipment: "Cable", cue: "Lead with your elbows and pull them toward your back pockets."),
        ExerciseDefinition(id: "pull-up", name: "Assisted Pull-Up", muscle: .back, equipment: "Pull-up bar", cue: "Begin by moving the shoulder blades, then drive elbows down."),
        ExerciseDefinition(id: "band-pulldown", name: "Band Lat Pulldown", muscle: .back, equipment: "Band", cue: "Keep ribs stacked and drive the elbows toward your sides."),
        ExerciseDefinition(id: "prone-lat-pull", name: "Prone Lat Pull", muscle: .back, equipment: "Bodyweight", cue: "Reach long, then sweep elbows toward your sides without shrugging."),

        ExerciseDefinition(id: "lateral-raise", name: "Cable Lateral Raise", muscle: .shoulders, equipment: "Cable", cue: "Lead with your elbow and stop just below shoulder height."),
        ExerciseDefinition(id: "db-lateral-raise", name: "Dumbbell Lateral Raise", muscle: .shoulders, equipment: "Dumbbells", cue: "Use a soft elbow and lift only through a controlled range."),
        ExerciseDefinition(id: "band-lateral-raise", name: "Band Lateral Raise", muscle: .shoulders, equipment: "Band", cue: "Keep tension smooth and stop before the shoulder hikes."),
        ExerciseDefinition(id: "face-pull", name: "Face Pull", muscle: .shoulders, equipment: "Cable", cue: "Pull toward eyebrow height and rotate your thumbs behind you."),
        ExerciseDefinition(id: "db-curl", name: "Dumbbell Curl", muscle: .arms, equipment: "Dumbbells", cue: "Keep your upper arm quiet and own the lowering phase."),
        ExerciseDefinition(id: "cable-curl", name: "Cable Curl", muscle: .arms, equipment: "Cable", cue: "Keep your shoulder still and finish without leaning back."),
        ExerciseDefinition(id: "band-curl", name: "Band Curl", muscle: .arms, equipment: "Band", cue: "Stand tall and keep tension through the full lowering phase."),
        ExerciseDefinition(id: "rope-pressdown", name: "Rope Pressdown", muscle: .arms, equipment: "Cable", cue: "Pin your elbows and split the rope at full extension."),
        ExerciseDefinition(id: "db-triceps-extension", name: "Dumbbell Triceps Extension", muscle: .arms, equipment: "Dumbbell", cue: "Keep elbows aimed forward and move through a comfortable range."),
        ExerciseDefinition(id: "close-grip-push-up", name: "Close-Grip Push-Up", muscle: .arms, equipment: "Bodyweight", cue: "Keep elbows close and press the floor away as one unit."),

        ExerciseDefinition(id: "plank", name: "Hardstyle Plank", muscle: .core, equipment: "Bodyweight", cue: "Squeeze glutes, pull elbows toward toes, and breathe behind the brace."),
        ExerciseDefinition(id: "dead-bug", name: "Dead Bug", muscle: .core, equipment: "Bodyweight", cue: "Keep your low back quiet while opposite limbs reach away."),
        ExerciseDefinition(id: "side-plank", name: "Side Plank", muscle: .core, equipment: "Bodyweight", cue: "Stack shoulders and hips, then make one long line from head to heel."),
        ExerciseDefinition(id: "pallof-press", name: "Pallof Press", muscle: .core, equipment: "Cable", cue: "Stay square and resist the cable as your hands travel away."),
        ExerciseDefinition(id: "band-pallof-press", name: "Band Pallof Press", muscle: .core, equipment: "Band", cue: "Stay tall and keep the torso still as your hands press away."),
    ]

    static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    private static let programming: [String: ExerciseProgrammingMetadata] = {
        var values: [String: ExerciseProgrammingMetadata] = [:]
        func add(
            _ ids: [String],
            pattern: MovementPattern,
            equipment: EquipmentOption,
            blockedBy: Set<TrainingConstraint> = [],
            increment: Double,
            tracksLoad: Bool = true
        ) {
            for id in ids {
                values[id] = ExerciseProgrammingMetadata(
                    pattern: pattern,
                    equipment: [equipment],
                    blockedBy: blockedBy,
                    incrementKG: increment,
                    tracksNumericLoad: tracksLoad
                )
            }
        }

        add(["back-squat"], pattern: .squat, equipment: .barbellRack, blockedBy: [.kneeSensitive, .lowerBackSensitive], increment: 2.5)
        add(["goblet-squat"], pattern: .squat, equipment: .dumbbells, blockedBy: [.kneeSensitive, .lowerBackSensitive], increment: 2)
        add(["leg-press"], pattern: .squat, equipment: .machines, blockedBy: [.kneeSensitive], increment: 5)
        add(["bodyweight-squat"], pattern: .squat, equipment: .bodyweight, blockedBy: [.kneeSensitive], increment: 0, tracksLoad: false)
        add(["trap-bar-deadlift"], pattern: .hinge, equipment: .trapBar, blockedBy: [.lowerBackSensitive], increment: 2.5)
        add(["romanian-deadlift"], pattern: .hinge, equipment: .barbellRack, blockedBy: [.lowerBackSensitive], increment: 2.5)
        add(["db-romanian-deadlift"], pattern: .hinge, equipment: .dumbbells, blockedBy: [.lowerBackSensitive], increment: 2)
        add(["cable-pull-through"], pattern: .hinge, equipment: .cables, blockedBy: [.lowerBackSensitive], increment: 2.5)
        add(["glute-bridge"], pattern: .hinge, equipment: .bodyweight, increment: 0, tracksLoad: false)
        add(["walking-lunge", "split-squat"], pattern: .singleLeg, equipment: .dumbbells, blockedBy: [.kneeSensitive], increment: 2)
        add(["reverse-lunge"], pattern: .singleLeg, equipment: .bodyweight, blockedBy: [.kneeSensitive], increment: 0, tracksLoad: false)
        add(["calf-raise"], pattern: .calves, equipment: .machines, increment: 2.5)
        add(["single-leg-calf-raise"], pattern: .calves, equipment: .bodyweight, increment: 0, tracksLoad: false)

        add(["barbell-bench"], pattern: .horizontalPush, equipment: .barbellRack, blockedBy: [.shoulderSensitive], increment: 2.5)
        add(["db-bench", "incline-db-press"], pattern: .horizontalPush, equipment: .dumbbells, increment: 2)
        add(["machine-chest-press"], pattern: .horizontalPush, equipment: .machines, increment: 2.5)
        add(["push-up"], pattern: .horizontalPush, equipment: .bodyweight, increment: 0, tracksLoad: false)
        add(["barbell-overhead-press"], pattern: .verticalPush, equipment: .barbellRack, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 2.5)
        add(["shoulder-press"], pattern: .verticalPush, equipment: .dumbbells, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 2)
        add(["machine-shoulder-press"], pattern: .verticalPush, equipment: .machines, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 2.5)
        add(["pike-push-up"], pattern: .verticalPush, equipment: .bodyweight, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 0, tracksLoad: false)

        add(["barbell-row"], pattern: .horizontalPull, equipment: .barbellRack, blockedBy: [.lowerBackSensitive], increment: 2.5)
        add(["cable-row"], pattern: .horizontalPull, equipment: .cables, increment: 2.5)
        add(["chest-supported-row", "one-arm-db-row"], pattern: .horizontalPull, equipment: .dumbbells, increment: 2)
        add(["machine-row"], pattern: .horizontalPull, equipment: .machines, increment: 2.5)
        add(["band-row"], pattern: .horizontalPull, equipment: .resistanceBands, increment: 0, tracksLoad: false)
        add(["prone-w-raise"], pattern: .horizontalPull, equipment: .bodyweight, increment: 0, tracksLoad: false)
        add(["lat-pulldown"], pattern: .verticalPull, equipment: .cables, increment: 2.5)
        add(["pull-up"], pattern: .verticalPull, equipment: .pullUpBar, increment: 0, tracksLoad: false)
        add(["band-pulldown"], pattern: .verticalPull, equipment: .resistanceBands, increment: 0, tracksLoad: false)
        add(["prone-lat-pull"], pattern: .verticalPull, equipment: .bodyweight, increment: 0, tracksLoad: false)

        add(["lateral-raise"], pattern: .lateralRaise, equipment: .cables, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 1)
        add(["db-lateral-raise"], pattern: .lateralRaise, equipment: .dumbbells, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 1)
        add(["band-lateral-raise"], pattern: .lateralRaise, equipment: .resistanceBands, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 0, tracksLoad: false)
        add(["face-pull"], pattern: .horizontalPull, equipment: .cables, increment: 1)
        add(["db-curl"], pattern: .armFlexion, equipment: .dumbbells, increment: 1)
        add(["cable-curl"], pattern: .armFlexion, equipment: .cables, increment: 1)
        add(["band-curl"], pattern: .armFlexion, equipment: .resistanceBands, increment: 0, tracksLoad: false)
        add(["rope-pressdown"], pattern: .armExtension, equipment: .cables, increment: 1)
        add(["db-triceps-extension"], pattern: .armExtension, equipment: .dumbbells, blockedBy: [.shoulderSensitive, .avoidOverhead], increment: 1)
        add(["close-grip-push-up"], pattern: .armExtension, equipment: .bodyweight, increment: 0, tracksLoad: false)

        add(["plank", "dead-bug"], pattern: .coreAntiExtension, equipment: .bodyweight, increment: 0, tracksLoad: false)
        add(["side-plank"], pattern: .coreAntiRotation, equipment: .bodyweight, increment: 0, tracksLoad: false)
        add(["pallof-press"], pattern: .coreAntiRotation, equipment: .cables, increment: 1)
        add(["band-pallof-press"], pattern: .coreAntiRotation, equipment: .resistanceBands, increment: 0, tracksLoad: false)
        return values
    }()

    static func metadata(for exercise: ExerciseDefinition) -> ExerciseProgrammingMetadata {
        programming[exercise.id] ?? ExerciseProgrammingMetadata(
            pattern: .coreAntiExtension,
            equipment: [.bodyweight],
            blockedBy: [],
            incrementKG: 1,
            tracksNumericLoad: exercise.equipment != "Bodyweight"
        )
    }

    static func incrementKG(
        for exercise: ExerciseDefinition,
        measurementSystem: MeasurementSystem
    ) -> Double {
        let metricIncrement = metadata(for: exercise).incrementKG
        guard metricIncrement > 0, measurementSystem == .imperial else {
            return metricIncrement
        }

        // Equipment sold in pound-based gyms generally moves in 2.5, 5, or
        // 10 lb steps. Keep storage canonical in kilograms while preserving
        // those exact human-facing jumps on iPhone and Apple Watch.
        let poundIncrement: Double
        if metricIncrement >= 4 {
            poundIncrement = 10
        } else if metricIncrement >= 1.5 {
            poundIncrement = 5
        } else {
            poundIncrement = 2.5
        }
        return poundIncrement / 2.204_622_621_8
    }

    static func isAvailable(_ exercise: ExerciseDefinition, equipment: Set<EquipmentOption>) -> Bool {
        let requirements = metadata(for: exercise).equipment
        let requiresBench = ["db-bench", "incline-db-press", "chest-supported-row"].contains(exercise.id)
        guard !requiresBench || equipment.contains(.bench) else { return false }
        return requirements.contains(.bodyweight) || !requirements.isDisjoint(with: equipment)
    }

    static func isPermitted(_ exercise: ExerciseDefinition, constraints: Set<TrainingConstraint>) -> Bool {
        metadata(for: exercise).blockedBy.isDisjoint(with: constraints)
    }

    static func usesNumericLoad(_ exercise: ExerciseDefinition) -> Bool {
        metadata(for: exercise).tracksNumericLoad
    }
}

private struct PersistedTrainingState: Codable {
    var weeklyPlan: [WorkoutPrescription]
    var programSummary: ProgramSummary?
    var adaptationDecisions: [AdaptationDecision]?
    var completedWorkouts: [WorkoutSession]
    var activeSession: WorkoutSession?
    var activeExerciseIndex: Int
    var restEndsAt: Date?
    var personalRecords: [PersonalRecord]
    var coachMessages: [CoachMessage]
    var coachInsight: String
    var planSignature: String

    init(
        weeklyPlan: [WorkoutPrescription],
        programSummary: ProgramSummary?,
        adaptationDecisions: [AdaptationDecision]?,
        completedWorkouts: [WorkoutSession],
        activeSession: WorkoutSession?,
        activeExerciseIndex: Int,
        restEndsAt: Date?,
        personalRecords: [PersonalRecord],
        coachMessages: [CoachMessage],
        coachInsight: String,
        planSignature: String
    ) {
        self.weeklyPlan = weeklyPlan
        self.programSummary = programSummary
        self.adaptationDecisions = adaptationDecisions
        self.completedWorkouts = completedWorkouts
        self.activeSession = activeSession
        self.activeExerciseIndex = activeExerciseIndex
        self.restEndsAt = restEndsAt
        self.personalRecords = personalRecords
        self.coachMessages = coachMessages
        self.coachInsight = coachInsight
        self.planSignature = planSignature
    }

    private enum CodingKeys: String, CodingKey {
        case weeklyPlan, programSummary, adaptationDecisions, completedWorkouts, activeSession
        case activeExerciseIndex, restEndsAt, personalRecords, coachMessages, coachInsight, planSignature
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        weeklyPlan = try values.decodeIfPresent([WorkoutPrescription].self, forKey: .weeklyPlan) ?? []
        programSummary = try values.decodeIfPresent(ProgramSummary.self, forKey: .programSummary)
        adaptationDecisions = try values.decodeIfPresent([AdaptationDecision].self, forKey: .adaptationDecisions)
        completedWorkouts = try values.decodeIfPresent([WorkoutSession].self, forKey: .completedWorkouts) ?? []
        activeSession = try values.decodeIfPresent(WorkoutSession.self, forKey: .activeSession)
        activeExerciseIndex = try values.decodeIfPresent(Int.self, forKey: .activeExerciseIndex) ?? 0
        restEndsAt = try values.decodeIfPresent(Date.self, forKey: .restEndsAt)
        personalRecords = try values.decodeIfPresent([PersonalRecord].self, forKey: .personalRecords) ?? []
        coachMessages = try values.decodeIfPresent([CoachMessage].self, forKey: .coachMessages) ?? [
            CoachMessage(
                role: .coach,
                text: "I’m watching your training pattern. Finish a session and I’ll tune next week around your performance."
            ),
        ]
        coachInsight = try values.decodeIfPresent(String.self, forKey: .coachInsight)
            ?? "Your week is balanced. Start with the recommended session and leave one clean rep in reserve."
        planSignature = try values.decodeIfPresent(String.self, forKey: .planSignature) ?? ""
    }
}

private struct LegacyCompletedWorkout: Codable {
    let date: Date
    let bodyParts: [String]
}
