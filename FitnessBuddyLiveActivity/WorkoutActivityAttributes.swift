import ActivityKit
import Foundation

/// Keep this schema byte-for-byte compatible with the app target's activity attributes.
/// The extension intentionally owns no app-only model dependencies.
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

extension WorkoutActivityAttributes.ContentState {
    var clampedWorkoutProgress: Double {
        guard totalWorkoutSets > 0 else { return isComplete ? 1 : 0 }
        return min(max(Double(completedSets) / Double(totalWorkoutSets), 0), 1)
    }

    var safeSetNumber: Int {
        guard totalSets > 0 else { return 0 }
        return min(max(setNumber, 1), totalSets)
    }
}
