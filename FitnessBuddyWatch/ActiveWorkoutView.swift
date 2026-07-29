import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var store: WatchWorkoutStore
    @EnvironmentObject private var health: WatchHealthWorkoutManager
    @State private var showFinishConfirmation = false
    @State private var showStopConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 11) {
                workoutHeader

                if health.heartRate > 0 || health.activeEnergyKCal > 0 {
                    healthStats
                }

                if let restEndsAt = store.restEndsAt {
                    RestTimerCard(endDate: restEndsAt) {
                        store.skipRest()
                    }
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                }

                if store.activeWorkout?.isComplete == true {
                    completionCard
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                } else if let exercise = store.currentExercise, let set = store.currentSet {
                    currentExerciseCard(exercise, set: set)
                    valueControls(set)

                    Button {
                        store.completeCurrentSet()
                    } label: {
                        Label(
                            set.reportedRIR == nil ? "SELECT RIR" : "COMPLETE SET \(set.setNumber)",
                            systemImage: set.reportedRIR == nil ? "dial.medium" : "checkmark"
                        )
                    }
                    .buttonStyle(WatchNeonButtonStyle())
                    .disabled(set.reportedRIR == nil)

                    setNavigator(exercise)
                }
            }
            .padding(.horizontal, 9)
            .padding(.bottom, 18)
        }
        .scrollIndicators(.hidden)
        .animation(.spring(response: 0.46, dampingFraction: 0.76), value: store.restEndsAt)
        .animation(.spring(response: 0.46, dampingFraction: 0.76), value: store.progress)
        .confirmationDialog("Finish this workout?", isPresented: $showFinishConfirmation) {
            Button("Finish Workout") { store.finishWorkout() }
            Button("Keep Training", role: .cancel) { }
        }
        .confirmationDialog("Stop this workout?", isPresented: $showStopConfirmation) {
            Button("End & Save Partial") { store.finishWorkout() }
            Button("Discard Workout", role: .destructive) { store.discardWorkout() }
            Button("Keep Training", role: .cancel) { }
        } message: {
            Text("Save your completed sets, or discard this session entirely.")
        }
    }

    private var workoutHeader: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(WatchPalette.iridescent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: WatchPalette.lime.opacity(0.45), radius: 5)
                Text("\(Int(store.progress * 100))")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
            }
            .frame(width: 45, height: 45)

            VStack(alignment: .leading, spacing: 1) {
                Text("LIVE / TRAINING")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .foregroundStyle(WatchPalette.lime)
                Text(store.activeWorkout?.title ?? "WORKOUT")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)
                if let workout = store.activeWorkout {
                    Text("\(workout.completedSetCount) OF \(workout.totalSetCount) SETS")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(WatchPalette.muted)
                }
            }
            Spacer(minLength: 0)

            Button {
                showStopConfirmation = true
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.white.opacity(0.10), in: Circle())
                    .overlay {
                        Circle().stroke(.white.opacity(0.14), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    private var healthStats: some View {
        HStack(spacing: 7) {
            if health.heartRate > 0 {
                Label {
                    Text("\(Int(health.heartRate)) BPM")
                } icon: {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                        .symbolEffect(.pulse, options: .repeating)
                }
            }
            if health.activeEnergyKCal > 0 {
                Label("\(Int(health.activeEnergyKCal)) KCAL", systemImage: "flame.fill")
                    .foregroundStyle(WatchPalette.lime)
            }
        }
        .font(.system(size: 9, weight: .black, design: .monospaced))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .watchGlassCard(cornerRadius: 14)
    }

    private func currentExerciseCard(_ exercise: WatchActiveExercise, set: WatchLoggedSet) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("EXERCISE \(store.currentExerciseIndex + 1)")
                    .foregroundStyle(WatchPalette.lime)
                Spacer()
                Text("SET \(set.setNumber)/\(exercise.sets.count)")
                    .foregroundStyle(WatchPalette.muted)
            }
            .font(.system(size: 8, weight: .bold, design: .monospaced))

            Text(exercise.name)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .tracking(-0.8)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            if !exercise.cue.isEmpty {
                Text(exercise.cue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(WatchPalette.muted)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .watchGlassCard(cornerRadius: 20)
    }

    private func valueControls(_ set: WatchLoggedSet) -> some View {
        VStack(spacing: 7) {
            HStack(spacing: 7) {
                SetValueControl(
                    label: set.tracksNumericLoad ? "WEIGHT \(set.measurementSystem.weightUnit)" : "LOAD",
                    value: set.tracksNumericLoad ? weightLabel(set.displayWeight) : "BODY",
                    decrement: { store.changeWeight(direction: -1) },
                    increment: { store.changeWeight(direction: 1) },
                    isEnabled: set.tracksNumericLoad
                )

                SetValueControl(
                    label: "REPS",
                    value: "\(set.reps)",
                    decrement: { store.changeReps(by: -1) },
                    increment: { store.changeReps(by: 1) }
                )
            }

            RIRControl(
                target: set.targetRIR,
                selection: set.reportedRIR,
                select: store.setRIR
            )
        }
    }

    private func setNavigator(_ exercise: WatchActiveExercise) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            WatchSectionLabel(index: "03", title: "Sets")
            HStack(spacing: 6) {
                ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { index, set in
                    Button {
                        store.select(exerciseIndex: store.currentExerciseIndex, setIndex: index)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(set.isComplete ? WatchPalette.lime : .white.opacity(0.06))
                            Circle()
                                .stroke(
                                    index == store.currentSetIndex ? WatchPalette.lime : .white.opacity(0.14),
                                    lineWidth: index == store.currentSetIndex ? 2 : 1
                                )
                            if set.isComplete {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.black)
                            } else {
                                Text("\(set.setNumber)")
                                    .foregroundStyle(.white)
                            }
                        }
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .frame(width: 29, height: 29)
                    }
                    .buttonStyle(.plain)
                    .disabled(set.isComplete)
                }
            }
        }
    }

    private var completionCard: some View {
        VStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(WatchPalette.iridescent)
                .symbolEffect(.bounce, options: .repeating.speed(0.45))
            Text("SESSION\nCOMPLETE")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .tracking(-0.7)
            Button("SAVE WORKOUT") {
                showFinishConfirmation = true
            }
            .buttonStyle(WatchNeonButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .watchGlassCard(cornerRadius: 20)
    }

    private func weightLabel(_ value: Double) -> String {
        let whole = value.rounded()
        return abs(value - whole) < 0.01 ? "\(Int(whole))" : String(format: "%.1f", value)
    }
}

private struct SetValueControl: View {
    let label: String
    let value: String
    let decrement: () -> Void
    let increment: () -> Void
    var isEnabled = true

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(WatchPalette.muted)
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .contentTransition(.numericText())
            HStack(spacing: 5) {
                controlButton(systemName: "minus", action: decrement)
                controlButton(systemName: "plus", action: increment)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .watchGlassCard(cornerRadius: 16)
        .opacity(isEnabled ? 1 : 0.72)
    }

    private func controlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(systemName == "plus" ? .black : .white)
                .frame(width: 31, height: 25)
                .background(systemName == "plus" ? WatchPalette.lime : .white.opacity(0.09), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct RIRControl: View {
    let target: Int
    let selection: Int?
    let select: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("REPS IN RESERVE")
                Spacer()
                Text("TARGET \(target)")
                    .foregroundStyle(WatchPalette.lime)
            }
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundStyle(WatchPalette.muted)

            HStack(spacing: 4) {
                ForEach(0...5, id: \.self) { value in
                    Button {
                        select(value)
                    } label: {
                        Text("\(value)")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundStyle(selection == value ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 25)
                            .background(
                                selection == value ? WatchPalette.lime : .white.opacity(0.08),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .watchGlassCard(cornerRadius: 16)
    }
}

private struct RestTimerCard: View {
    let endDate: Date
    let skip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(Int(endDate.timeIntervalSince(context.date).rounded(.up)), 0)

            HStack(spacing: 11) {
                ZStack {
                    Circle()
                        .fill(WatchPalette.lime.opacity(0.12))
                    Image(systemName: "timer")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(WatchPalette.lime)
                        .symbolEffect(.pulse, options: .repeating)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 0) {
                    Text("REST")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(WatchPalette.muted)
                    Text(String(format: "%d:%02d", remaining / 60, remaining % 60))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(WatchPalette.lime)
                        .contentTransition(.numericText(countsDown: true))
                }

                Spacer(minLength: 0)

                Button("SKIP", action: skip)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
            }
            .padding(11)
            .watchGlassCard(cornerRadius: 18)
        }
    }
}
