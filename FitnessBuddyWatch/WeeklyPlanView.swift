import SwiftUI

struct WeeklyPlanView: View {
    @EnvironmentObject private var store: WatchWorkoutStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    brandHeader

                    if let next = store.nextWorkout {
                        WatchSectionLabel(index: "01", title: "Up next")
                        nextWorkoutCard(next)
                    }

                    WatchSectionLabel(index: "02", title: "Training week")

                    if store.weeklyPlan.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.weeklyPlan) { workout in
                            NavigationLink {
                                WorkoutPlanDetailView(plan: workout)
                            } label: {
                                workoutRow(workout)
                            }
                            .buttonStyle(.plain)
                            .disabled(store.isCompleted(workout))
                        }
                    }
                }
                .padding(.horizontal, 9)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 7) {
                Text("✳")
                    .font(.system(size: 23, weight: .black))
                    .foregroundStyle(WatchPalette.iridescent)
                    .shadow(color: WatchPalette.lime.opacity(0.45), radius: 8)

                Text("EARNED")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(-0.6)

                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(store.isReachable ? WatchPalette.lime : WatchPalette.muted)
                    .frame(width: 5, height: 5)
                    .shadow(color: WatchPalette.lime.opacity(store.isReachable ? 0.8 : 0), radius: 5)
                Text(store.connectionLabel)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(WatchPalette.muted)
        }
        .padding(.top, 3)
    }

    private func nextWorkoutCard(_ workout: WatchWorkoutPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.scheduledDate, format: .dateTime.weekday(.wide))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(WatchPalette.lime)
                    Text(workout.title)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .minimumScaleFactor(0.72)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                if workout.isAIEnhanced {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(WatchPalette.iridescent)
                }
            }

            HStack(spacing: 8) {
                Label("\(workout.estimatedMinutes) MIN", systemImage: "timer")
                Label("\(workout.exercises.count) MOVES", systemImage: "figure.strengthtraining.traditional")
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .foregroundStyle(WatchPalette.muted)

            Button("START WORKOUT") {
                store.start(workout)
            }
            .buttonStyle(WatchNeonButtonStyle())
            .disabled(store.isCompleted(workout))
        }
        .padding(13)
        .watchGlassCard(cornerRadius: 20)
    }

    private func workoutRow(_ workout: WatchWorkoutPlan) -> some View {
        HStack(spacing: 9) {
            VStack(spacing: -1) {
                Text(workout.scheduledDate, format: .dateTime.weekday(.abbreviated))
                Text(workout.scheduledDate, format: .dateTime.day())
                    .foregroundStyle(.white)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(WatchPalette.lime)
            .frame(width: 31)

            Rectangle()
                .fill(WatchPalette.iridescent)
                .frame(width: 2, height: 31)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.title)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .lineLimit(1)
                Text("\(workout.exercises.count) EXERCISES  /  \(workout.estimatedMinutes) MIN")
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchPalette.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 1)
            if store.isCompleted(workout) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(WatchPalette.lime)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(WatchPalette.lime)
            }
        }
        .padding(10)
        .watchGlassCard(cornerRadius: 15)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "iphone.and.arrow.forward")
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(WatchPalette.iridescent)
            Text("OPEN EARNED\nON YOUR IPHONE")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
            Text("Your training week will appear here.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(WatchPalette.muted)
                .multilineTextAlignment(.center)
            Button("REQUEST PLAN") {
                store.requestPlanRefresh()
            }
            .buttonStyle(WatchNeonButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .watchGlassCard(cornerRadius: 20)
    }
}

struct WorkoutPlanDetailView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    let plan: WatchWorkoutPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                Text(plan.scheduledDate, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchPalette.lime)

                Text(plan.title)
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .tracking(-1)

                if !plan.subtitle.isEmpty {
                    Text(plan.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(WatchPalette.muted)
                }

                if !plan.rationale.isEmpty {
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(WatchPalette.lime)
                        Text(plan.rationale)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(11)
                    .watchGlassCard(cornerRadius: 15)
                }

                WatchSectionLabel(index: "01", title: "Exercises")

                ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, item in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(WatchPalette.lime)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.exercise.name)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                            Text("\(item.sets) × \(item.repLabel)  /  \(item.restSeconds)S REST")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundStyle(WatchPalette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .watchGlassCard(cornerRadius: 14)
                }

                Button("START WORKOUT") {
                    store.start(plan)
                }
                .buttonStyle(WatchNeonButtonStyle())
                .disabled(store.isCompleted(plan))
                .padding(.top, 3)
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 15)
        }
        .scrollIndicators(.hidden)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}
