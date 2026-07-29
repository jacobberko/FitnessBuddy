import ActivityKit
import SwiftUI
import WidgetKit

struct FitnessBuddyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .activityBackgroundTint(LiveActivityPalette.black)
                .activitySystemActionForegroundColor(LiveActivityPalette.lime)
                .widgetURL(workoutURL(sessionID: context.attributes.sessionID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedBrandView()
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedPrimaryMetric(context: context)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.workoutTitle.uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.58))
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedWorkoutView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalWorkoutView(context: context)
            }
            .keylineTint(LiveActivityPalette.lime)
            .widgetURL(workoutURL(sessionID: context.attributes.sessionID))
        }
    }

    private func workoutURL(sessionID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "berko-fitnessbuddy2"
        components.host = "workout"
        components.path = "/\(sessionID)"
        return components.url
    }
}

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var state: WorkoutActivityAttributes.ContentState { context.state }

    var body: some View {
        ZStack {
            LiveActivityBackdrop()

            VStack(alignment: .leading, spacing: 13) {
                LockScreenHeader(context: context)

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(state.isComplete ? "SESSION / COMPLETE" : "NOW / EXERCISE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .tracking(1.25)
                            .foregroundStyle(LiveActivityPalette.lime)

                        Text(state.isComplete ? "WORKOUT COMPLETE" : state.exerciseName.uppercased())
                            .font(.system(size: 23, weight: .black, design: .default))
                            .tracking(-0.7)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.72)
                            .contentTransition(.interpolate)
                    }

                    Spacer(minLength: 5)

                    WorkoutProgressRing(
                        progress: state.clampedWorkoutProgress,
                        size: 48,
                        lineWidth: 4
                    )
                }

                WorkoutProgressBar(progress: state.clampedWorkoutProgress, height: 5)

                HStack(spacing: 9) {
                    MetricPill(label: "SET", value: state.totalSets > 0 ? "\(state.safeSetNumber)/\(state.totalSets)" : "—")
                    MetricPill(label: "TOTAL", value: "\(state.completedSets)/\(state.totalWorkoutSets)")

                    Spacer(minLength: 4)

                    LockScreenStatus(state: state)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        if state.isComplete {
            return "\(context.attributes.workoutTitle) complete. \(state.completedSets) sets finished."
        }

        let exercise = "\(state.exerciseName), set \(state.safeSetNumber) of \(state.totalSets)."
        if state.restEndsAt != nil {
            return "\(exercise) Rest timer active."
        }
        return "\(exercise) \(state.completedSets) of \(state.totalWorkoutSets) workout sets complete."
    }
}

private struct LockScreenHeader: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        HStack(spacing: 9) {
            FitnessBuddyMark(size: 21)

            VStack(alignment: .leading, spacing: 1) {
                Text("EARNED")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .tracking(0.8)
                Text(context.attributes.workoutTitle.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.48))
                    .lineLimit(1)
            }

            Spacer()

            if context.state.isComplete {
                Label("DONE", systemImage: "checkmark")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(LiveActivityPalette.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(LiveActivityPalette.lime, in: Capsule(style: .continuous))
            } else {
                HStack(spacing: 6) {
                    Circle()
                        .fill(LiveActivityPalette.lime)
                        .frame(width: 6, height: 6)
                        .shadow(color: LiveActivityPalette.lime, radius: 4)
                    Text(context.attributes.startedAt, style: .timer)
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .liveActivityGlass(cornerRadius: 14, tint: LiveActivityPalette.lime)
            }
        }
    }
}

private struct MetricPill: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 5) {
            Text(label)
                .foregroundStyle(.white.opacity(0.45))
            Text(value)
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .liveActivityGlass(cornerRadius: 12)
    }
}

private struct LockScreenStatus: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 6) {
            if state.isComplete {
                Image(systemName: "trophy.fill")
                Text("NICE WORK")
            } else if let restEndsAt = state.restEndsAt {
                Image(systemName: "timer")
                Text("REST")
                RestCountdownText(endDate: restEndsAt)
            } else {
                Image(systemName: "bolt.fill")
                Text("ACTIVE")
            }
        }
        .font(.system(size: 10, weight: .black, design: .monospaced))
        .foregroundStyle(state.isComplete ? LiveActivityPalette.black : LiveActivityPalette.lime)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            state.isComplete ? LiveActivityPalette.lime : LiveActivityPalette.lime.opacity(0.11),
            in: Capsule(style: .continuous)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(LiveActivityPalette.lime.opacity(state.isComplete ? 0 : 0.35), lineWidth: 0.75)
        )
    }
}

private struct ExpandedBrandView: View {
    var body: some View {
        HStack(spacing: 7) {
            FitnessBuddyMark(size: 22)
            Text("FB//")
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.leading, 2)
        .accessibilityLabel("Earned")
    }
}

private struct ExpandedPrimaryMetric: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if context.state.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(LiveActivityPalette.lime)
            } else if let restEndsAt = context.state.restEndsAt {
                Text("REST")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(LiveActivityPalette.lime.opacity(0.72))
                RestCountdownText(endDate: restEndsAt)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(LiveActivityPalette.lime)
            } else {
                Text("ACTIVE")
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(LiveActivityPalette.lime.opacity(0.72))
                Text(context.attributes.startedAt, style: .timer)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
        .frame(minWidth: 50, alignment: .trailing)
    }
}

private struct ExpandedWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var state: WorkoutActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(state.isComplete ? "SESSION COMPLETE" : state.exerciseName.uppercased())
                        .font(.system(size: 17, weight: .black))
                        .tracking(-0.35)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.interpolate)

                    Text(state.isComplete ? "ALL SETS LOGGED" : "SET \(state.safeSetNumber) / \(state.totalSets)")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .tracking(0.9)
                        .foregroundStyle(LiveActivityPalette.lime)
                }

                Spacer(minLength: 6)

                Text("\(state.completedSets)/\(state.totalWorkoutSets)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            WorkoutProgressBar(progress: state.clampedWorkoutProgress, height: 5)
        }
        .padding(.horizontal, 4)
        .padding(.top, 3)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

private struct CompactLeadingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        WorkoutProgressRing(
            progress: context.state.clampedWorkoutProgress,
            size: 23,
            lineWidth: 2.25
        )
        .padding(.leading, 1)
        .accessibilityLabel("Workout progress")
        .accessibilityValue(
            "\(Int((context.state.clampedWorkoutProgress * 100).rounded())) percent"
        )
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        Group {
            if context.state.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .black))
            } else if let restEndsAt = context.state.restEndsAt {
                RestCountdownText(endDate: restEndsAt)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
            } else {
                Text("\(context.state.safeSetNumber)/\(context.state.totalSets)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .contentTransition(.numericText())
            }
        }
        .foregroundStyle(LiveActivityPalette.lime)
        .frame(minWidth: 28)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    private var compactAccessibilityLabel: String {
        if context.state.isComplete { return "Workout complete" }
        if context.state.restEndsAt != nil { return "Rest timer" }
        return "Set \(context.state.safeSetNumber) of \(context.state.totalSets)"
    }
}

private struct MinimalWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    var body: some View {
        ZStack {
            WorkoutProgressRing(
                progress: context.state.clampedWorkoutProgress,
                size: 22,
                lineWidth: 2.2
            )

            if context.state.isComplete {
                Circle()
                    .fill(LiveActivityPalette.lime)
                    .frame(width: 17, height: 17)
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(LiveActivityPalette.black)
            }
        }
        .accessibilityLabel(context.state.isComplete ? "Workout complete" : "Active workout")
    }
}
