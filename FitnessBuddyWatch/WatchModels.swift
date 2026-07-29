import Foundation

// MARK: - Phone payload DTOs

enum WatchMeasurementSystem: String, Codable, Hashable {
    case imperial
    case metric

    var weightUnit: String { self == .imperial ? "LB" : "KG" }

    func displayWeight(fromKilograms kilograms: Double) -> Double {
        self == .imperial ? kilograms * 2.204_622_621_8 : kilograms
    }
}

/// A Watch-owned representation of `WorkoutPrescription`.
///
/// The iPhone app sends its complete model as JSON. Keeping a small, tolerant DTO
/// here avoids coupling the Watch target to iOS-only source files and lets older
/// plans continue decoding when the phone adds optional fields.
struct WatchWorkoutPlan: Codable, Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let scheduledDate: Date
    let estimatedMinutes: Int
    let focus: [String]
    let exercises: [WatchExercisePrescription]
    let isAIEnhanced: Bool
    let rationale: String

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case scheduledDate
        case estimatedMinutes
        case focus
        case exercises
        case isAIEnhanced
        case rationale
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.lossyUUID(forKey: .id) ?? UUID()
        title = (try? values.decode(String.self, forKey: .title)) ?? "WORKOUT"
        subtitle = (try? values.decode(String.self, forKey: .subtitle)) ?? ""
        scheduledDate = values.lossyDate(forKey: .scheduledDate) ?? Date()
        estimatedMinutes = max((try? values.decode(Int.self, forKey: .estimatedMinutes)) ?? 45, 1)
        focus = (try? values.decode([String].self, forKey: .focus)) ?? []
        exercises = (try? values.decode([WatchExercisePrescription].self, forKey: .exercises)) ?? []
        isAIEnhanced = (try? values.decode(Bool.self, forKey: .isAIEnhanced)) ?? false
        rationale = (try? values.decode(String.self, forKey: .rationale)) ?? ""
    }

    init(
        id: UUID,
        title: String,
        subtitle: String,
        scheduledDate: Date,
        estimatedMinutes: Int,
        focus: [String],
        exercises: [WatchExercisePrescription],
        isAIEnhanced: Bool,
        rationale: String
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
}

struct WatchExercisePrescription: Codable, Identifiable, Hashable {
    let id: UUID
    let exercise: WatchExerciseDefinition
    let sets: Int
    let repMin: Int
    let repMax: Int
    let targetWeightKG: Double
    let restSeconds: Int
    let targetRIR: Int
    let measurementSystem: WatchMeasurementSystem
    let incrementKG: Double
    let tracksNumericLoad: Bool

    var repLabel: String {
        repMin == repMax ? "\(repMin)" : "\(repMin)–\(repMax)"
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exercise
        case sets
        case repMin
        case repMax
        case targetWeightKG
        case restSeconds
        case targetRIR
        case measurementSystem
        case incrementKG
        case tracksNumericLoad
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = values.lossyUUID(forKey: .id) ?? UUID()
        exercise = (try? values.decode(WatchExerciseDefinition.self, forKey: .exercise)) ?? .unknown
        sets = max((try? values.decode(Int.self, forKey: .sets)) ?? 1, 1)
        repMin = max((try? values.decode(Int.self, forKey: .repMin)) ?? 1, 1)
        repMax = max((try? values.decode(Int.self, forKey: .repMax)) ?? repMin, repMin)
        targetWeightKG = max((try? values.decode(Double.self, forKey: .targetWeightKG)) ?? 0, 0)
        restSeconds = max((try? values.decode(Int.self, forKey: .restSeconds)) ?? 60, 0)
        targetRIR = min(max((try? values.decode(Int.self, forKey: .targetRIR)) ?? 2, 0), 5)
        measurementSystem = (try? values.decode(WatchMeasurementSystem.self, forKey: .measurementSystem)) ?? .metric
        incrementKG = max((try? values.decode(Double.self, forKey: .incrementKG)) ?? 2.5, 0)
        tracksNumericLoad = (try? values.decode(Bool.self, forKey: .tracksNumericLoad)) ?? (incrementKG > 0)
    }

    init(
        id: UUID,
        exercise: WatchExerciseDefinition,
        sets: Int,
        repMin: Int,
        repMax: Int,
        targetWeightKG: Double,
        restSeconds: Int,
        targetRIR: Int = 2,
        measurementSystem: WatchMeasurementSystem = .metric,
        incrementKG: Double = 2.5,
        tracksNumericLoad: Bool = true
    ) {
        self.id = id
        self.exercise = exercise
        self.sets = sets
        self.repMin = repMin
        self.repMax = repMax
        self.targetWeightKG = targetWeightKG
        self.restSeconds = restSeconds
        self.targetRIR = targetRIR
        self.measurementSystem = measurementSystem
        self.incrementKG = incrementKG
        self.tracksNumericLoad = tracksNumericLoad
    }
}

struct WatchExerciseDefinition: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let muscle: String
    let equipment: String
    let cue: String

    static let unknown = WatchExerciseDefinition(
        id: "unknown",
        name: "EXERCISE",
        muscle: "Training",
        equipment: "",
        cue: "Move with control."
    )

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case muscle
        case equipment
        case cue
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? values.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? values.decode(String.self, forKey: .name)) ?? "EXERCISE"
        muscle = (try? values.decode(String.self, forKey: .muscle)) ?? "Training"
        equipment = (try? values.decode(String.self, forKey: .equipment)) ?? ""
        cue = (try? values.decode(String.self, forKey: .cue)) ?? "Move with control."
    }

    init(id: String, name: String, muscle: String, equipment: String, cue: String) {
        self.id = id
        self.name = name
        self.muscle = muscle
        self.equipment = equipment
        self.cue = cue
    }
}

// MARK: - Watch workout state

struct WatchActiveWorkout: Codable, Equatable {
    let sessionID: UUID
    let prescriptionID: UUID
    let title: String
    let startedAt: Date
    var exercises: [WatchActiveExercise]

    var completedSetCount: Int {
        exercises.flatMap(\.sets).filter(\.isComplete).count
    }

    var totalSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.count }
    }

    var isComplete: Bool {
        totalSetCount > 0 && completedSetCount == totalSetCount
    }

    init(plan: WatchWorkoutPlan) {
        sessionID = UUID()
        prescriptionID = plan.id
        title = plan.title
        startedAt = Date()
        exercises = plan.exercises.map(WatchActiveExercise.init)
    }
}

struct WatchActiveExercise: Codable, Identifiable, Equatable {
    let id: UUID
    let exerciseID: String
    let name: String
    let cue: String
    var sets: [WatchLoggedSet]

    init(prescription: WatchExercisePrescription) {
        id = prescription.id
        exerciseID = prescription.exercise.id
        name = prescription.exercise.name
        cue = prescription.exercise.cue
        sets = (1...prescription.sets).map { number in
            WatchLoggedSet(
                setNumber: number,
                targetRepMin: prescription.repMin,
                targetRepMax: prescription.repMax,
                weightKG: prescription.targetWeightKG,
                reps: prescription.repMin,
                restSeconds: prescription.restSeconds,
                targetRIR: prescription.targetRIR,
                measurementSystem: prescription.measurementSystem,
                incrementKG: prescription.incrementKG,
                tracksNumericLoad: prescription.tracksNumericLoad
            )
        }
    }
}

struct WatchLoggedSet: Codable, Identifiable, Equatable {
    let id: UUID
    let setNumber: Int
    let targetRepMin: Int
    let targetRepMax: Int
    var weightKG: Double
    var reps: Int
    var isComplete: Bool
    var completedAt: Date?
    let restSeconds: Int
    let targetRIR: Int
    var reportedRIR: Int?
    let measurementSystem: WatchMeasurementSystem
    let incrementKG: Double
    let tracksNumericLoad: Bool

    var displayWeight: Double {
        measurementSystem.displayWeight(fromKilograms: weightKG)
    }

    init(
        id: UUID = UUID(),
        setNumber: Int,
        targetRepMin: Int,
        targetRepMax: Int,
        weightKG: Double,
        reps: Int,
        isComplete: Bool = false,
        completedAt: Date? = nil,
        restSeconds: Int,
        targetRIR: Int = 2,
        reportedRIR: Int? = nil,
        measurementSystem: WatchMeasurementSystem = .metric,
        incrementKG: Double = 2.5,
        tracksNumericLoad: Bool = true
    ) {
        self.id = id
        self.setNumber = setNumber
        self.targetRepMin = targetRepMin
        self.targetRepMax = targetRepMax
        self.weightKG = weightKG
        self.reps = reps
        self.isComplete = isComplete
        self.completedAt = completedAt
        self.restSeconds = restSeconds
        self.targetRIR = min(max(targetRIR, 0), 5)
        self.reportedRIR = reportedRIR.map { min(max($0, 0), 5) }
        self.measurementSystem = measurementSystem
        self.incrementKG = max(incrementKG, 0)
        self.tracksNumericLoad = tracksNumericLoad
    }

    private enum CodingKeys: String, CodingKey {
        case id, setNumber, targetRepMin, targetRepMax, weightKG, reps
        case isComplete, completedAt, restSeconds, targetRIR, reportedRIR
        case measurementSystem, incrementKG, tracksNumericLoad
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        setNumber = try values.decode(Int.self, forKey: .setNumber)
        targetRepMin = try values.decode(Int.self, forKey: .targetRepMin)
        targetRepMax = try values.decode(Int.self, forKey: .targetRepMax)
        weightKG = max(try values.decode(Double.self, forKey: .weightKG), 0)
        reps = max(try values.decode(Int.self, forKey: .reps), 0)
        isComplete = try values.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        completedAt = try values.decodeIfPresent(Date.self, forKey: .completedAt)
        restSeconds = max(try values.decodeIfPresent(Int.self, forKey: .restSeconds) ?? 60, 0)
        targetRIR = min(max(try values.decodeIfPresent(Int.self, forKey: .targetRIR) ?? 2, 0), 5)
        reportedRIR = try values.decodeIfPresent(Int.self, forKey: .reportedRIR)
            .map { min(max($0, 0), 5) }
        measurementSystem = try values.decodeIfPresent(
            WatchMeasurementSystem.self,
            forKey: .measurementSystem
        ) ?? .metric
        incrementKG = max(try values.decodeIfPresent(Double.self, forKey: .incrementKG) ?? 2.5, 0)
        tracksNumericLoad = try values.decodeIfPresent(Bool.self, forKey: .tracksNumericLoad)
            ?? (incrementKG > 0)
    }
}

private extension KeyedDecodingContainer {
    func lossyUUID(forKey key: Key) -> UUID? {
        if let uuid = try? decode(UUID.self, forKey: key) { return uuid }
        if let value = try? decode(String.self, forKey: key) { return UUID(uuidString: value) }
        return nil
    }

    func lossyDate(forKey key: Key) -> Date? {
        if let date = try? decode(Date.self, forKey: key) { return date }
        if let referenceSeconds = try? decode(Double.self, forKey: key) {
            return Date(timeIntervalSinceReferenceDate: referenceSeconds)
        }
        if let value = try? decode(String.self, forKey: key) {
            return ISO8601DateFormatter().date(from: value)
        }
        return nil
    }
}
