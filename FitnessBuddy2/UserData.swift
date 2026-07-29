import Foundation
import SwiftUI

enum FitnessExperience: String, Codable, CaseIterable, Identifiable, Sendable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: "Beginner"
        case .intermediate: "Intermediate"
        case .advanced: "Advanced"
        }
    }

    var detail: String {
        switch self {
        case .beginner: "Building technique and consistency"
        case .intermediate: "Progressing load and volume"
        case .advanced: "Performance-first programming"
        }
    }

    var levelMultiplier: Double {
        switch self {
        case .beginner: 0.75
        case .intermediate: 1.0
        case .advanced: 1.2
        }
    }
}

enum FitnessGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case strength
    case muscle
    case generalFitness
    case athleticPerformance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strength: "Get stronger"
        case .muscle: "Build muscle"
        case .generalFitness: "Feel fitter"
        case .athleticPerformance: "Move better"
        }
    }

    var shortTitle: String {
        switch self {
        case .strength: "Strength"
        case .muscle: "Hypertrophy"
        case .generalFitness: "Fitness"
        case .athleticPerformance: "Athletic"
        }
    }

    var systemImage: String {
        switch self {
        case .strength: "bolt.fill"
        case .muscle: "figure.strengthtraining.traditional"
        case .generalFitness: "heart.fill"
        case .athleticPerformance: "figure.run"
        }
    }
}

enum MeasurementSystem: String, Codable, CaseIterable, Identifiable, Sendable {
    case imperial
    case metric

    var id: String { rawValue }
    var title: String { self == .imperial ? "LB / FT" : "KG / CM" }
    var weightUnit: String { self == .imperial ? "lb" : "kg" }
}

enum EquipmentOption: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case barbellRack
    case dumbbells
    case bench
    case cables
    case machines
    case trapBar
    case resistanceBands
    case pullUpBar
    case bodyweight

    var id: String { rawValue }

    var title: String {
        switch self {
        case .barbellRack: "Barbell + rack"
        case .dumbbells: "Dumbbells"
        case .bench: "Training bench"
        case .cables: "Cable station"
        case .machines: "Machines"
        case .trapBar: "Trap bar"
        case .resistanceBands: "Resistance bands"
        case .pullUpBar: "Pull-up bar"
        case .bodyweight: "Bodyweight"
        }
    }

    var detail: String {
        switch self {
        case .barbellRack: "Squat, bench and barbell work"
        case .dumbbells: "Fixed or adjustable pairs"
        case .bench: "Flat or adjustable support"
        case .cables: "Pulldowns, rows and accessories"
        case .machines: "Selectorized or plate-loaded"
        case .trapBar: "Trap-bar pulls and carries"
        case .resistanceBands: "Loop or handled bands"
        case .pullUpBar: "Pull-ups and hanging work"
        case .bodyweight: "No equipment required"
        }
    }

    var systemImage: String {
        switch self {
        case .barbellRack: "figure.strengthtraining.traditional"
        case .dumbbells: "dumbbell.fill"
        case .bench: "rectangle.fill"
        case .cables: "arrow.up.and.down.and.arrow.left.and.right"
        case .machines: "gearshape.2.fill"
        case .trapBar: "square.dashed"
        case .resistanceBands: "oval"
        case .pullUpBar: "figure.highintensity.intervaltraining"
        case .bodyweight: "figure.core.training"
        }
    }
}

enum TrainingConstraint: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case shoulderSensitive
    case kneeSensitive
    case lowerBackSensitive
    case avoidOverhead
    case avoidHighImpact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shoulderSensitive: "Shoulder-sensitive"
        case .kneeSensitive: "Knee-sensitive"
        case .lowerBackSensitive: "Lower-back-sensitive"
        case .avoidOverhead: "Avoid overhead work"
        case .avoidHighImpact: "Avoid high impact"
        }
    }

    var detail: String {
        switch self {
        case .shoulderSensitive: "Favor shoulder-friendly angles and grips"
        case .kneeSensitive: "Favor tolerable ranges and stable variations"
        case .lowerBackSensitive: "Limit unsupported loading and deep fatigue"
        case .avoidOverhead: "Use horizontal or landmine-style pressing"
        case .avoidHighImpact: "Keep conditioning low-impact"
        }
    }

    var systemImage: String {
        switch self {
        case .shoulderSensitive: "figure.arms.open"
        case .kneeSensitive: "figure.walk.motion"
        case .lowerBackSensitive: "figure.flexibility"
        case .avoidOverhead: "arrow.down.to.line"
        case .avoidHighImpact: "waveform.path.ecg"
        }
    }
}

struct LiftBaseline: Codable, Hashable, Identifiable, Sendable {
    var exerciseID: String
    var weightKG: Double
    var reps: Int
    var rir: Int?
    var performedAt: Date

    var id: String { exerciseID }

    var estimatedOneRepMaxKG: Double {
        let effectiveReps = min(max(reps + (rir ?? 2), 1), 12)
        return max(weightKG, 0) * (1 + Double(effectiveReps) / 30)
    }
}

struct UserProfileSnapshot: Codable, Hashable, Sendable {
    var name: String
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var experience: FitnessExperience
    var goal: FitnessGoal
    var sessionsPerWeek: Int
    var sessionMinutes: Int
    var measurementSystem: MeasurementSystem
    var trainingAgeMonths: Int
    var preferredWeekdays: Set<Int>
    var equipment: Set<EquipmentOption>
    var constraints: Set<TrainingConstraint>
    var baselines: [LiftBaseline]
    var recoveryRating: Int

    init(
        name: String,
        age: Int,
        heightCM: Double,
        weightKG: Double,
        experience: FitnessExperience,
        goal: FitnessGoal,
        sessionsPerWeek: Int,
        sessionMinutes: Int,
        measurementSystem: MeasurementSystem,
        trainingAgeMonths: Int? = nil,
        preferredWeekdays: Set<Int>? = nil,
        equipment: Set<EquipmentOption> = Set(EquipmentOption.allCases),
        constraints: Set<TrainingConstraint> = [],
        baselines: [LiftBaseline] = [],
        recoveryRating: Int = 3
    ) {
        let normalizedSessions = min(max(sessionsPerWeek, 2), 6)
        var normalizedWeekdays = Set((preferredWeekdays ?? Self.defaultWeekdays(for: normalizedSessions))
            .filter { (1...7).contains($0) })
        for day in Self.defaultWeekdays(for: normalizedSessions) where normalizedWeekdays.count < normalizedSessions {
            normalizedWeekdays.insert(day)
        }
        normalizedWeekdays = Set(normalizedWeekdays.sorted().prefix(normalizedSessions))

        self.name = name
        self.age = min(max(age, 18), 100)
        self.heightCM = min(max(heightCM, 120), 230)
        self.weightKG = min(max(weightKG, 30), 300)
        self.experience = experience
        self.goal = goal
        self.sessionsPerWeek = normalizedWeekdays.count
        self.sessionMinutes = min(max(sessionMinutes, 30), 90)
        self.measurementSystem = measurementSystem
        self.trainingAgeMonths = min(max(trainingAgeMonths ?? Self.defaultTrainingAge(for: experience), 0), 600)
        self.preferredWeekdays = normalizedWeekdays
        self.equipment = equipment.isEmpty ? [.bodyweight] : equipment
        self.constraints = constraints
        self.baselines = baselines.map { baseline in
            LiftBaseline(
                exerciseID: baseline.exerciseID,
                weightKG: max(baseline.weightKG, 0),
                reps: min(max(baseline.reps, 1), 30),
                rir: baseline.rir.map { min(max($0, 0), 5) },
                performedAt: baseline.performedAt
            )
        }
        self.recoveryRating = min(max(recoveryRating, 1), 5)
    }

    private static func defaultTrainingAge(for experience: FitnessExperience) -> Int {
        switch experience {
        case .beginner: 3
        case .intermediate: 18
        case .advanced: 48
        }
    }

    private static func defaultWeekdays(for sessions: Int) -> Set<Int> {
        switch sessions {
        case ...2: [2, 5]
        case 3: [1, 3, 5]
        case 4: [1, 3, 5, 6]
        case 5: [1, 2, 3, 5, 6]
        default: [1, 2, 3, 4, 5, 6]
        }
    }
}

@MainActor
final class UserData: ObservableObject {
    @Published var name: String { didSet { persist() } }
    @Published var age: Int { didSet { persist() } }
    @Published var heightCM: Double { didSet { persist() } }
    @Published var weightKG: Double { didSet { persist() } }
    @Published var experience: FitnessExperience { didSet { persist() } }
    @Published var goal: FitnessGoal { didSet { persist() } }
    @Published var sessionsPerWeek: Int { didSet { persist() } }
    @Published var sessionMinutes: Int { didSet { persist() } }
    @Published var measurementSystem: MeasurementSystem { didSet { persist() } }
    @Published var trainingAgeMonths: Int { didSet { persist() } }
    @Published var preferredWeekdays: Set<Int> { didSet { persist() } }
    @Published var equipment: Set<EquipmentOption> { didSet { persist() } }
    @Published var constraints: Set<TrainingConstraint> { didSet { persist() } }
    @Published var baselines: [LiftBaseline] { didSet { persist() } }
    @Published var recoveryRating: Int { didSet { persist() } }
    @Published var hasCompletedOnboarding: Bool { didSet { persist() } }
    @Published var healthKitEnabled: Bool { didSet { persist() } }

    private let defaults: UserDefaults
    private let profileKey = "fitnessBuddy.profile.v3"
    private static let currentOnboardingVersion = 2

    var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? "Athlete"
    }

    var weightDisplay: Double {
        displayWeight(kg: weightKG)
    }

    var heightDisplay: Double {
        measurementSystem == .imperial ? heightCM / 2.54 : heightCM
    }

    var experienceLevel: String { experience.title }

    var snapshot: UserProfileSnapshot {
        UserProfileSnapshot(
            name: name,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            experience: experience,
            goal: goal,
            sessionsPerWeek: sessionsPerWeek,
            sessionMinutes: sessionMinutes,
            measurementSystem: measurementSystem,
            trainingAgeMonths: trainingAgeMonths,
            preferredWeekdays: preferredWeekdays,
            equipment: equipment,
            constraints: constraints,
            baselines: baselines,
            recoveryRating: recoveryRating
        )
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let isUITest = ProcessInfo.processInfo.environment["FITNESS_BUDDY_UI_TEST_RESET"] == "1"

        if let data = defaults.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(StoredProfile.self, from: data) {
            let storedSessions = min(max(profile.sessionsPerWeek, 2), 6)
            var storedWeekdays = Set((profile.preferredWeekdays ?? Self.defaultWeekdays(for: storedSessions))
                .filter { (1...7).contains($0) })
            for day in Self.defaultWeekdays(for: storedSessions) where storedWeekdays.count < storedSessions {
                storedWeekdays.insert(day)
            }
            storedWeekdays = Set(storedWeekdays.sorted().prefix(storedSessions))
            name = profile.name
            age = min(max(profile.age, 18), 100)
            heightCM = min(max(profile.heightCM, 120), 230)
            weightKG = min(max(profile.weightKG, 30), 300)
            experience = profile.experience
            goal = profile.goal
            sessionsPerWeek = storedWeekdays.count
            sessionMinutes = min(max(profile.sessionMinutes, 30), 90)
            measurementSystem = profile.measurementSystem
            trainingAgeMonths = min(max(profile.trainingAgeMonths ?? Self.defaultTrainingAge(for: profile.experience), 0), 600)
            preferredWeekdays = storedWeekdays
            let storedEquipment = profile.equipment ?? Set(EquipmentOption.allCases)
            equipment = storedEquipment.isEmpty ? [.bodyweight] : storedEquipment
            constraints = profile.constraints ?? []
            baselines = (profile.baselines ?? []).map { baseline in
                LiftBaseline(
                    exerciseID: baseline.exerciseID,
                    weightKG: max(baseline.weightKG, 0),
                    reps: min(max(baseline.reps, 1), 30),
                    rir: baseline.rir.map { min(max($0, 0), 5) },
                    performedAt: baseline.performedAt
                )
            }
            recoveryRating = min(max(profile.recoveryRating ?? 3, 1), 5)
            hasCompletedOnboarding = isUITest
                || (profile.onboardingVersion == Self.currentOnboardingVersion && profile.hasCompletedOnboarding)
            healthKitEnabled = profile.healthKitEnabled
            return
        }

        // Preserve the useful parts of the original app's UserDefaults profile.
        name = defaults.string(forKey: "userName") ?? ""
        age = min(max(Int(defaults.string(forKey: "userAge") ?? "") ?? 28, 18), 100)
        heightCM = Self.parseLegacyHeight(defaults.string(forKey: "userHeight")) ?? 175
        let legacyWeightLB = Double(defaults.string(forKey: "userWeight") ?? "") ?? 165
        weightKG = legacyWeightLB / 2.204_622_621_8
        let legacyExperience = Self.parseLegacyExperience(defaults.string(forKey: "userExperienceLevel"))
        let defaultSessionsPerWeek = 4
        experience = legacyExperience
        goal = .strength
        sessionsPerWeek = defaultSessionsPerWeek
        sessionMinutes = 55
        measurementSystem = .imperial
        trainingAgeMonths = Self.defaultTrainingAge(for: legacyExperience)
        preferredWeekdays = Self.defaultWeekdays(for: defaultSessionsPerWeek)
        equipment = Set(EquipmentOption.allCases)
        constraints = []
        #if DEBUG
        let screenshotBaselines = ProcessInfo.processInfo.environment["FITNESS_BUDDY_APP_STORE_SCREENSHOTS"] == "1" ? [
            LiftBaseline(
                exerciseID: "barbell-bench",
                weightKG: 61.2,
                reps: 8,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
            LiftBaseline(
                exerciseID: "back-squat",
                weightKG: 83.9,
                reps: 6,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
            LiftBaseline(
                exerciseID: "romanian-deadlift",
                weightKG: 72.6,
                reps: 8,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
            LiftBaseline(
                exerciseID: "barbell-row",
                weightKG: 49.9,
                reps: 8,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
            LiftBaseline(
                exerciseID: "shoulder-press",
                weightKG: 20.4,
                reps: 10,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
            LiftBaseline(
                exerciseID: "lat-pulldown",
                weightKG: 49.9,
                reps: 10,
                rir: 2,
                performedAt: Date().addingTimeInterval(-7 * 86_400)
            ),
        ] : []
        #else
        let screenshotBaselines: [LiftBaseline] = []
        #endif
        baselines = screenshotBaselines
        recoveryRating = 3
        // The original setup did not collect enough information to build the
        // formal program, so existing installs complete the new intake once.
        hasCompletedOnboarding = isUITest
        healthKitEnabled = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
    }

    func setDisplayedWeight(_ value: Double) {
        weightKG = measurementSystem == .imperial ? value / 2.204_622_621_8 : value
    }

    func displayWeight(kg: Double) -> Double {
        measurementSystem == .imperial ? kg * 2.204_622_621_8 : kg
    }

    func setDisplayedHeight(_ value: Double) {
        heightCM = measurementSystem == .imperial ? value * 2.54 : value
    }

    func baseline(for exerciseID: String) -> LiftBaseline? {
        baselines.first(where: { $0.exerciseID == exerciseID })
    }

    func setBaseline(exerciseID: String, displayWeight: Double, reps: Int, rir: Int?) {
        let weightKG = measurementSystem == .imperial ? displayWeight / 2.204_622_621_8 : displayWeight
        let existingIndex = baselines.firstIndex(where: { $0.exerciseID == exerciseID })
        let baseline = LiftBaseline(
            exerciseID: exerciseID,
            weightKG: max(weightKG, 0),
            reps: min(max(reps, 1), 30),
            rir: rir.map { min(max($0, 0), 5) },
            performedAt: existingIndex.map { baselines[$0].performedAt } ?? Date()
        )
        if let existingIndex {
            baselines[existingIndex] = baseline
        } else {
            baselines.append(baseline)
        }
    }

    func removeBaseline(exerciseID: String) {
        baselines.removeAll(where: { $0.exerciseID == exerciseID })
    }

    private func persist() {
        let profile = StoredProfile(
            name: name,
            age: age,
            heightCM: heightCM,
            weightKG: weightKG,
            experience: experience,
            goal: goal,
            sessionsPerWeek: sessionsPerWeek,
            sessionMinutes: sessionMinutes,
            measurementSystem: measurementSystem,
            trainingAgeMonths: trainingAgeMonths,
            preferredWeekdays: preferredWeekdays,
            equipment: equipment,
            constraints: constraints,
            baselines: baselines,
            recoveryRating: recoveryRating,
            onboardingVersion: Self.currentOnboardingVersion,
            hasCompletedOnboarding: hasCompletedOnboarding,
            healthKitEnabled: healthKitEnabled
        )
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: profileKey)
    }

    private static func parseLegacyExperience(_ value: String?) -> FitnessExperience {
        guard let value else { return .beginner }
        if value.localizedCaseInsensitiveContains("advanced") { return .advanced }
        if value.localizedCaseInsensitiveContains("intermediate") { return .intermediate }
        return .beginner
    }

    private static func defaultTrainingAge(for experience: FitnessExperience) -> Int {
        switch experience {
        case .beginner: 3
        case .intermediate: 18
        case .advanced: 48
        }
    }

    private static func defaultWeekdays(for sessions: Int) -> Set<Int> {
        switch sessions {
        case ...2: [2, 5]
        case 3: [1, 3, 5]
        case 4: [1, 3, 5, 6]
        case 5: [1, 2, 3, 5, 6]
        default: [1, 2, 3, 4, 5, 6]
        }
    }

    private static func parseLegacyHeight(_ value: String?) -> Double? {
        guard let value else { return nil }
        let numbers = value.split(whereSeparator: { !$0.isNumber }).compactMap { Double($0) }
        guard numbers.count >= 2 else { return nil }
        return (numbers[0] * 12 + numbers[1]) * 2.54
    }
}

private struct StoredProfile: Codable {
    var name: String
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var experience: FitnessExperience
    var goal: FitnessGoal
    var sessionsPerWeek: Int
    var sessionMinutes: Int
    var measurementSystem: MeasurementSystem
    var trainingAgeMonths: Int?
    var preferredWeekdays: Set<Int>?
    var equipment: Set<EquipmentOption>?
    var constraints: Set<TrainingConstraint>?
    var baselines: [LiftBaseline]?
    var recoveryRating: Int?
    var onboardingVersion: Int?
    var hasCompletedOnboarding: Bool
    var healthKitEnabled: Bool
}
