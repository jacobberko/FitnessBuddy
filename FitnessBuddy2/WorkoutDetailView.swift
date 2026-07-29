import SwiftUI
import UIKit

/// Identifies the numeric field that currently holds focus. The set fields use
/// `.numberPad`/`.decimalPad`, which have no return key, so focus has to be
/// tracked explicitly to give the keyboard a way to be dismissed.
enum SetFieldFocus: Hashable {
    case weight(Int)
    case reps(Int)
    case rir(Int)

    var setIndex: Int {
        switch self {
        case .weight(let index), .reps(let index), .rir(let index): index
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var liveActivity: WorkoutLiveActivityManager
    @EnvironmentObject private var watchSync: WatchSyncManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showExitConfirmation = false
    @State private var showCompletion = false
    @State private var showPR = false
    @State private var setPulse = false
    @FocusState private var focusedField: SetFieldFocus?

    var body: some View {
        ZStack {
            IridescentBackground()

            if let session = workoutData.activeSession {
                activeWorkout(session)
                    .blur(radius: showCompletion ? 16 : 0)
                    .scaleEffect(showCompletion ? 0.96 : 1)

                if showCompletion {
                    WorkoutCompletionView(session: session, onDone: finishWorkout)
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                        .zIndex(5)
                }
            } else {
                ProgressView().tint(FBPalette.lime)
            }

            if showPR {
                prToast
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled()
        .onAppear {
            if let session = workoutData.activeSession {
                liveActivity.start(session: session, exerciseIndex: workoutData.activeExerciseIndex)
            }
        }
        .onChange(of: workoutData.activeSession) { _, session in
            guard let session else { return }
            liveActivity.update(
                session: session,
                exerciseIndex: workoutData.activeExerciseIndex,
                restEndsAt: workoutData.restEndsAt
            )
        }
        .onChange(of: workoutData.activeExerciseIndex) { _, _ in updateLiveActivity() }
        .onChange(of: workoutData.restEndsAt) { _, _ in updateLiveActivity() }
        .confirmationDialog("End this workout?", isPresented: $showExitConfirmation, titleVisibility: .visible) {
            Button("Discard workout", role: .destructive) {
                liveActivity.cancel()
                workoutData.discardActiveWorkout()
            }
            Button("Keep training", role: .cancel) { }
        } message: {
            Text("Completed sets in this active session will be removed.")
        }
    }

    private func activeWorkout(_ session: WorkoutSession) -> some View {
        VStack(spacing: 0) {
            workoutHeader(session)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    exerciseNavigator(session)

                    if let exercise = workoutData.currentExercise {
                        exerciseHeading(exercise)
                        setTable(exercise, exerciseIndex: workoutData.activeExerciseIndex)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, workoutData.restEndsAt == nil ? 120 : 210)
            }
            .scrollDismissesKeyboard(.interactively)

            actionBar(session)
        }
        .toolbar { keyboardBar }
        .overlay(alignment: .bottom) {
            if let end = workoutData.restEndsAt, end > Date() {
                RestTimerCard(endDate: end) {
                    workoutData.skipRest()
                    FitnessHaptics.selection()
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.42, dampingFraction: 0.86), value: workoutData.restEndsAt)
    }

    /// The numeric keypads have no return key. This bar is the only way to
    /// dismiss them, and it doubles as one-tap entry for reps in reserve —
    /// the value that gates completing a set.
    @ToolbarContentBuilder
    private var keyboardBar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            if case .rir(let setIndex) = focusedField {
                HStack(spacing: 6) {
                    Text("RIR")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(0...5, id: \.self) { value in
                        Button {
                            workoutData.updateRIR(
                                exerciseIndex: workoutData.activeExerciseIndex,
                                setIndex: setIndex,
                                rir: value
                            )
                            FitnessHaptics.selection()
                            focusedField = nil
                        } label: {
                            Text("\(value)")
                                .font(.system(size: 15, weight: .black, design: .monospaced))
                                .frame(width: 34, height: 32)
                                .background(Color.accentColor.opacity(0.16), in: RoundedRectangle(cornerRadius: 9))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(value) reps in reserve")
                    }
                }
            }

            Spacer()

            Button("Done") { focusedField = nil }
                .font(.system(size: 16, weight: .bold))
        }
    }

    private func workoutHeader(_ session: WorkoutSession) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    showExitConfirmation = true
                    FitnessHaptics.warning()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .fitnessGlass(cornerRadius: 22, tint: .white, interactive: true)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("close-workout-button")

                Spacer()

                VStack(spacing: 3) {
                    Text("ACTIVE / SESSION")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(FBPalette.lime)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(FitnessFormatters.duration(context.date.timeIntervalSince(session.startedAt)))
                            .font(.system(size: 17, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                ZStack {
                    Circle().stroke(Color.white.opacity(0.1), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: workoutData.workoutProgress)
                        .stroke(FBPalette.iridescentAngular, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(workoutData.workoutProgress * 100))")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(FBPalette.iridescent)
                        .frame(width: max(0, proxy.size.width * workoutData.workoutProgress))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(FBPalette.black.opacity(0.76))
    }

    private func exerciseNavigator(_ session: WorkoutSession) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) {
                ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, exercise in
                    Button {
                        workoutData.moveToExercise(index)
                        FitnessHaptics.selection()
                    } label: {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(exercise.isComplete ? FBPalette.lime : Color.white.opacity(0.1))
                                    .frame(width: 27, height: 27)
                                Text("\(index + 1)")
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundStyle(exercise.isComplete ? .black : .white)
                            }
                            if index == workoutData.activeExerciseIndex {
                                Text(exercise.exercise.name.uppercased())
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 9)
                        .frame(height: 43)
                        .background(
                            index == workoutData.activeExerciseIndex ? Color.white.opacity(0.09) : Color.clear,
                            in: Capsule()
                        )
                        .overlay {
                            if index == workoutData.activeExerciseIndex {
                                Capsule().stroke(FBPalette.lime.opacity(0.42), lineWidth: 0.8)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .contentMargins(.horizontal, 1)
        .padding(.top, 12)
    }

    private func exerciseHeading(_ exercise: SessionExercise) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(workoutData.activeExerciseIndex + 1) / \(workoutData.activeSession?.exercises.count ?? 0)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.lime)
                Spacer()
                Text(exercise.exercise.muscle.rawValue.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }

            Text(exercise.exercise.name.uppercased())
                .editorialTitle(size: 38)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.68)

            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "scope")
                    .foregroundStyle(FBPalette.cyan)
                Text(exercise.cue)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineSpacing(3)
            }
            .padding(15)
            .fitnessGlass(cornerRadius: 20, tint: FBPalette.cyan)

            if let firstSet = exercise.sets.first {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        EffortPill(
                            icon: "gauge.with.dots.needle.50percent",
                            text: "TARGET \(firstSet.effectiveTargetRIR) RIR",
                            tint: FBPalette.lime
                        )
                        if let loadSource = exercise.loadSource {
                            EffortPill(
                                icon: "scalemass.fill",
                                text: loadSource.uppercased(),
                                tint: FBPalette.violet
                            )
                        }
                    }

                    if let decisionNote = exercise.decisionNote {
                        Text(decisionNote)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(FBPalette.muted)
                            .lineSpacing(2)
                    }
                }
            }
        }
    }

    private func setTable(_ exercise: SessionExercise, exerciseIndex: Int) -> some View {
        VStack(spacing: 10) {
            HStack {
                Text("SET")
                Spacer()
                Text("PREVIOUS")
                    .frame(width: 58)
                Text(userData.measurementSystem.weightUnit.uppercased())
                    .frame(width: 54)
                Text("REPS")
                    .frame(width: 46)
                Text("RIR*")
                    .frame(width: 38)
                Color.clear.frame(width: 36)
            }
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(FBPalette.muted)
            .padding(.horizontal, 10)

            Text("* Enter the good reps you had left before completing each set. Unreported effort never earns an automatic progression.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(FBPalette.muted)
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)

            ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { setIndex, set in
                ActiveSetRow(
                    set: set,
                    setIndex: setIndex,
                    focus: $focusedField,
                    previous: previousValue(exerciseID: exercise.exercise.id, setIndex: setIndex),
                    units: userData.measurementSystem,
                    weight: Binding(
                        get: { currentDisplayWeight(exerciseIndex: exerciseIndex, setIndex: setIndex) },
                        set: { workoutData.updateWeight(exerciseIndex: exerciseIndex, setIndex: setIndex, displayValue: $0, units: userData.measurementSystem) }
                    ),
                    reps: Binding(
                        get: { currentReps(exerciseIndex: exerciseIndex, setIndex: setIndex) },
                        set: { workoutData.updateReps(exerciseIndex: exerciseIndex, setIndex: setIndex, reps: $0) }
                    ),
                    rir: Binding(
                        get: { currentRIR(exerciseIndex: exerciseIndex, setIndex: setIndex) },
                        set: { value in
                            guard let value else { return }
                            workoutData.updateRIR(exerciseIndex: exerciseIndex, setIndex: setIndex, rir: value)
                        }
                    )
                ) {
                    let isPR = workoutData.toggleSet(exerciseIndex: exerciseIndex, setIndex: setIndex)
                    if isPR {
                        FitnessHaptics.personalRecord()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) { showPR = true }
                        Task {
                            try? await Task.sleep(for: .seconds(2.2))
                            await MainActor.run { withAnimation { showPR = false } }
                        }
                    } else {
                        FitnessHaptics.setComplete()
                    }
                    setPulse.toggle()
                    updateLiveActivity()
                }
                .sensoryFeedback(.impact(weight: .heavy), trigger: setPulse)
            }
        }
    }

    private func actionBar(_ session: WorkoutSession) -> some View {
        HStack(spacing: 12) {
            if workoutData.isWorkoutReadyToFinish {
                Button {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) { showCompletion = true }
                    FitnessHaptics.personalRecord()
                } label: {
                    NeonActionLabel(title: "Finish workout", icon: "checkmark")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    workoutData.moveToNextExercise()
                    FitnessHaptics.selection()
                } label: {
                    HStack {
                        Text(workoutData.isCurrentExerciseComplete ? "NEXT EXERCISE" : "LOG EVERY SET")
                            .font(.system(size: 13, weight: .black))
                            .fontWidth(.expanded)
                        Spacer()
                        Image(systemName: workoutData.isCurrentExerciseComplete ? "arrow.right" : "checkmark.square")
                    }
                    .foregroundStyle(workoutData.isCurrentExerciseComplete ? .black : FBPalette.muted)
                    .padding(.horizontal, 20)
                    .frame(height: 58)
                    .background(workoutData.isCurrentExerciseComplete ? FBPalette.lime : Color.white.opacity(0.075), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!workoutData.isCurrentExerciseComplete)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var prToast: some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .foregroundStyle(.black)
                .frame(width: 38, height: 38)
                .background(.white, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("NEW PERSONAL RECORD")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                Text("Strongest logged set for this movement")
                    .font(.system(size: 10, weight: .semibold))
            }
            Spacer()
        }
        .foregroundStyle(.black)
        .padding(13)
        .background(FBPalette.iridescent, in: Capsule())
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func currentDisplayWeight(exerciseIndex: Int, setIndex: Int) -> Double {
        guard let set = workoutData.activeSession?.exercises[safe: exerciseIndex]?.sets[safe: setIndex] else { return 0 }
        return userData.measurementSystem == .imperial ? set.weightKG * 2.204_622_621_8 : set.weightKG
    }

    private func currentReps(exerciseIndex: Int, setIndex: Int) -> Int {
        workoutData.activeSession?.exercises[safe: exerciseIndex]?.sets[safe: setIndex]?.reps ?? 0
    }

    private func currentRIR(exerciseIndex: Int, setIndex: Int) -> Int? {
        workoutData.activeSession?.exercises[safe: exerciseIndex]?.sets[safe: setIndex]?.reportedRIR
    }

    private func previousValue(exerciseID: String, setIndex: Int) -> String {
        guard let previous = workoutData.completedWorkouts
            .lazy
            .flatMap(\.exercises)
            .first(where: { $0.exercise.id == exerciseID })?
            .sets[safe: setIndex] else { return "—" }
        return "\(FitnessFormatters.weight(previous.weightKG, units: userData.measurementSystem, includeUnit: false))×\(previous.reps)"
    }

    private func updateLiveActivity() {
        guard let session = workoutData.activeSession else { return }
        liveActivity.update(
            session: session,
            exerciseIndex: workoutData.activeExerciseIndex,
            restEndsAt: workoutData.restEndsAt
        )
    }

    private func finishWorkout() {
        guard let session = workoutData.finishActiveWorkout() else { return }
        liveActivity.end(session: session)
        watchSync.sync(completed: session)
        // Workouts started on Apple Watch are saved to Health by the Watch itself.
        guard !session.isWatchOriginated else { return }
        Task {
            _ = await healthKit.save(session)
        }
    }
}

private struct EffortPill: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 8, weight: .black, design: .monospaced))
            .lineLimit(1)
            .minimumScaleFactor(0.65)
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .frame(height: 34)
            .background(tint.opacity(0.13), in: Capsule())
            .overlay { Capsule().stroke(tint.opacity(0.35), lineWidth: 0.7) }
    }
}

private struct ActiveSetRow: View {
    let set: WorkoutSetLog
    let setIndex: Int
    @FocusState.Binding var focus: SetFieldFocus?
    let previous: String
    let units: MeasurementSystem
    @Binding var weight: Double
    @Binding var reps: Int
    @Binding var rir: Int?
    let action: () -> Void

    /// Tapping a field should replace its value, not append to it. Without
    /// this, tapping "3" and typing "8" leaves "83".
    private func selectAllOnFocus(_ isFocused: Bool) {
        guard isFocused else { return }
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(
                #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
            )
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(set.isComplete ? .black : .white)
                .frame(width: 32)

            Spacer(minLength: 0)

            Text(previous)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(set.isComplete ? Color.black.opacity(0.55) : FBPalette.muted)
                .frame(width: 58)

            TextField(
                "0",
                value: $weight,
                format: .number.precision(.fractionLength(0...1))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 15, weight: .black, design: .monospaced))
            .frame(width: 54, height: 42)
            .foregroundStyle(set.isComplete ? .black : .white)
            .background(set.isComplete ? Color.black.opacity(0.08) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            .disabled(set.isComplete)
            .focused($focus, equals: .weight(setIndex))
            .onChange(of: focus == .weight(setIndex)) { _, new in selectAllOnFocus(new) }

            TextField("0", value: $reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .frame(width: 46, height: 42)
                .foregroundStyle(set.isComplete ? .black : .white)
                .background(set.isComplete ? Color.black.opacity(0.08) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .disabled(set.isComplete)
                .focused($focus, equals: .reps(setIndex))
                .onChange(of: focus == .reps(setIndex)) { _, new in selectAllOnFocus(new) }
                .accessibilityLabel("Repetitions")
                .accessibilityIdentifier("reps-field-\(set.setNumber)")

            TextField("—", value: $rir, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .frame(width: 38, height: 42)
                .foregroundStyle(set.isComplete ? .black : FBPalette.cyan)
                .background(set.isComplete ? Color.black.opacity(0.08) : Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .disabled(set.isComplete)
                .focused($focus, equals: .rir(setIndex))
                .onChange(of: focus == .rir(setIndex)) { _, new in selectAllOnFocus(new) }
                .accessibilityLabel("Repetitions in reserve")
                .accessibilityIdentifier("rir-field-\(set.setNumber)")

            Button {
                focus = nil
                action()
            } label: {
                Image(systemName: set.isComplete ? "checkmark" : "circle")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(set.isComplete ? .black : FBPalette.lime)
                    .frame(width: 36, height: 40)
                    .background(set.isComplete ? .clear : Color.white.opacity(0.075), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!set.isComplete && rir == nil)
            .opacity(!set.isComplete && rir == nil ? 0.45 : 1)
            .accessibilityIdentifier("complete-set-\(set.setNumber)")
            .accessibilityHint(rir == nil ? "Enter your actual reps in reserve before completing this set." : "")
        }
        .padding(.horizontal, 10)
        .frame(height: 62)
        .background(set.isComplete ? FBPalette.lime : Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            if !set.isComplete {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(FBPalette.hairline, lineWidth: 0.7)
            }
        }
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: set.isComplete)
    }
}

private struct RestTimerCard: View {
    let endDate: Date
    let skip: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(Int(endDate.timeIntervalSince(context.date)), 0)
            HStack(spacing: 16) {
                ZStack {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: min(Double(remaining) / 120, 1))
                        .stroke(FBPalette.iridescentAngular, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remaining)")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text("REST / RECOVER")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(FBPalette.lime)
                    Text("Breathe. Reset. Own the next set.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button("SKIP", action: skip)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(FBPalette.lime, in: Capsule())
            }
            .padding(14)
            .fitnessGlass(cornerRadius: 28, tint: FBPalette.lime, interactive: true)
            .onChange(of: remaining) { _, value in
                if value == 0 { skip() }
            }
        }
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
