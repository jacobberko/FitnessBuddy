import SwiftUI

struct TodayView: View {
    @Binding var selectedTab: AppTab

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @EnvironmentObject private var healthKit: HealthKitManager

    @State private var heroAppeared = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 28) {
                ScreenHeader(
                    kicker: Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                    title: "Ready, \(userData.firstName)?",
                    actionIcon: "bell.fill"
                ) { FitnessHaptics.selection() }
                .padding(.top, 10)

                readinessStrip

                if let active = workoutData.activeSession {
                    resumeCard(active)
                } else if let workout = workoutData.todayWorkout {
                    WorkoutHeroCard(workout: workout) {
                        workoutData.startWorkout(workout)
                    }
                    .scaleEffect(heroAppeared ? 1 : 0.96)
                    .opacity(heroAppeared ? 1 : 0)
                }

                weekRail

                VStack(spacing: 14) {
                    SectionLabel(index: "02", title: "This week", trailing: "Live totals")
                    HStack(spacing: 12) {
                        MetricBlock(
                            value: "\(workoutData.weeklyCompletedCount)",
                            label: "SESSIONS",
                            detail: "OF \(userData.sessionsPerWeek)",
                            accent: FBPalette.lime
                        )
                        MetricBlock(
                            value: FitnessFormatters.compactVolume(workoutData.weeklyVolumeKG, units: userData.measurementSystem),
                            label: "VOLUME",
                            detail: userData.measurementSystem.weightUnit.uppercased(),
                            accent: FBPalette.cyan
                        )
                        MetricBlock(
                            value: "\(workoutData.streak)",
                            label: "STREAK",
                            detail: "DAYS",
                            accent: FBPalette.magenta
                        )
                    }
                }

                coachCard

                healthCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
        }
        .background(Color.clear)
        .navigationBarHidden(true)
        .onAppear {
            withAnimation(.spring(response: 0.72, dampingFraction: 0.82).delay(0.08)) {
                heroAppeared = true
            }
        }
    }

    private var readinessStrip: some View {
        HStack(spacing: 16) {
            ReadinessRing(value: workoutData.readiness)

            VStack(alignment: .leading, spacing: 5) {
                Text("READINESS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.25)
                    .foregroundStyle(FBPalette.muted)
                Text(workoutData.readiness > 0.72 ? "PRIMED TO TRAIN" : "MOVE WITH INTENT")
                    .font(.system(size: 16, weight: .black))
                    .fontWidth(.expanded)
                Text("Based on recovery and this week’s load")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
            }
            Spacer()
        }
        .foregroundStyle(.white)
        .padding(16)
        .fitnessGlass(cornerRadius: 25, tint: workoutData.readiness > 0.72 ? FBPalette.lime : FBPalette.magenta)
    }

    private func resumeCard(_ session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            SectionLabel(index: "LIVE", title: "Workout in progress", trailing: "\(Int(workoutData.workoutProgress * 100))%")
            Text(session.title)
                .editorialTitle(size: 34)
                .foregroundStyle(.white)
            ProgressView(value: workoutData.workoutProgress)
                .tint(FBPalette.lime)
            Button {
                // Assigning the same item refreshes the full-screen presentation binding.
                workoutData.activeSession = session
            } label: {
                NeonActionLabel(title: "Resume workout", icon: "play.fill")
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .fitnessGlass(cornerRadius: 30, tint: FBPalette.lime, interactive: true)
    }

    private var weekRail: some View {
        VStack(spacing: 16) {
            SectionLabel(index: "01", title: "Your training week", trailing: "\(workoutData.weeklyPlan.count) sessions")

            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let planned = workoutData.weeklyPlan.contains { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
                    let completed = workoutData.completedWorkouts.contains { Calendar.current.isDate($0.startedAt, inSameDayAs: date) }
                    VStack(spacing: 9) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(FBPalette.muted)
                        ZStack {
                            Circle()
                                .fill(completed ? FBPalette.lime : (planned ? Color.white.opacity(0.12) : .clear))
                                .frame(width: 34, height: 34)
                            if planned && !completed {
                                Circle().stroke(FBPalette.lime.opacity(0.72), lineWidth: 1)
                                    .frame(width: 34, height: 34)
                            }
                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(completed ? .black : .white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var coachCard: some View {
        Button {
            withAnimation(.snappy) { selectedTab = .coach }
        } label: {
            HStack(spacing: 15) {
                ZStack {
                    Circle().fill(FBPalette.iridescent).frame(width: 53, height: 53)
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("WEEKLY SIGNAL / ON-DEVICE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.25)
                        .foregroundStyle(FBPalette.lime)
                    Text(workoutData.coachInsight)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.white)
            }
            .padding(17)
            .fitnessGlass(cornerRadius: 26, tint: FBPalette.violet, interactive: true)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var healthCard: some View {
        if userData.healthKitEnabled || healthKit.status == .authorized {
            HStack {
                Image(systemName: "heart.fill").foregroundStyle(.red)
                Text("APPLE HEALTH CONNECTED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                Spacer()
                Text("\(healthKit.recentHealthWorkouts.count) RECENT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }
            .foregroundStyle(.white)
            .padding(16)
            .fitnessGlass(cornerRadius: 22, tint: .red)
        }
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }
}

struct TrainView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @State private var search = ""
    @State private var selectedMuscle: MuscleGroup?

    var filteredExercises: [ExerciseDefinition] {
        ExerciseCatalog.all.filter { exercise in
            (search.isEmpty || exercise.name.localizedCaseInsensitiveContains(search))
                && (selectedMuscle == nil || exercise.muscle == selectedMuscle)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ScreenHeader(kicker: "Program / Week 01", title: "Train")
                    .padding(.top, 10)

                if let summary = workoutData.programSummary {
                    ProgramBlueprintCard(
                        summary: summary,
                        latestDecision: workoutData.adaptationDecisions.first
                    )
                }

                VStack(spacing: 13) {
                    SectionLabel(index: "02", title: "Current program", trailing: userData.goal.shortTitle)
                    ForEach(Array(workoutData.weeklyPlan.enumerated()), id: \.element.id) { index, workout in
                        let isCompleted = workoutData.completedWorkouts.contains { $0.prescriptionID == workout.id }
                        PlanRow(
                            index: index + 1,
                            workout: workout,
                            isCompleted: isCompleted,
                            isLocked: workoutData.activeSession != nil
                        ) {
                            workoutData.startWorkout(workout)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    SectionLabel(index: "03", title: "Exercise system", trailing: "\(filteredExercises.count) moves")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            MuscleFilter(title: "ALL", selected: selectedMuscle == nil) { selectedMuscle = nil }
                            ForEach(MuscleGroup.allCases) { muscle in
                                MuscleFilter(title: muscle.rawValue.uppercased(), selected: selectedMuscle == muscle) {
                                    withAnimation(.snappy) { selectedMuscle = muscle }
                                }
                            }
                        }
                    }
                    .contentMargins(.horizontal, 1)

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(FBPalette.muted)
                        TextField("Search exercises", text: $search)
                            .textInputAutocapitalization(.never)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .fitnessGlass(cornerRadius: 24, tint: FBPalette.cyan, interactive: true)

                    ForEach(filteredExercises) { exercise in
                        ExerciseLibraryRow(exercise: exercise)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
        }
        .navigationBarHidden(true)
    }
}

struct WorkoutHeroCard: View {
    let workout: WorkoutPrescription
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                // The mark ships with a transparent surround so it can float on
                // the app background elsewhere; this card wants it full-bleed,
                // so it supplies its own solid backdrop.
                Image("IridescentMark")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 255)
                    .background(FBPalette.black)
                    .clipped()
                    .overlay {
                        LinearGradient(colors: [.clear, FBPalette.black.opacity(0.12), FBPalette.black], startPoint: .top, endPoint: .bottom)
                    }

                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(workout.isAIEnhanced ? "ADAPTED" : "TODAY / RECOMMENDED")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(FBPalette.lime)
                        Spacer()
                        Text("\(workout.estimatedMinutes) MIN")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                    Text(workout.title)
                        .editorialTitle(size: 38)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                    Text(workout.subtitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(FBPalette.muted)

                    if !workout.rationale.isEmpty {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "scope")
                                .foregroundStyle(FBPalette.cyan)
                            Text(workout.rationale)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(FBPalette.muted)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(20)
            }

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(workout.focus.prefix(3)) { muscle in
                        Text(muscle.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.075), in: Capsule())
                    }
                    Spacer()
                    Text("\(workout.exercises.count) MOVES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(FBPalette.muted)
                }
                Button(action: action) {
                    NeonActionLabel(title: "Start workout", icon: "play.fill")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("start-workout-button")
                .sensoryFeedback(.impact(weight: .heavy), trigger: false)
            }
            .padding(20)
        }
        .background(FBPalette.elevated.opacity(0.82))
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(FBPalette.iridescent.opacity(0.42), lineWidth: 1)
        }
        .shadow(color: FBPalette.lime.opacity(0.14), radius: 28, y: 16)
    }
}

struct ReadinessRing: View {
    let value: Double
    @State private var animatedValue = 0.0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: animatedValue)
                .stroke(FBPalette.iridescentAngular, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(value * 100))")
                .font(.system(size: 17, weight: .black, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 66, height: 66)
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.78)) { animatedValue = value }
        }
    }
}

struct MetricBlock: View {
    let value: String
    let label: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 25, weight: .black))
                .fontWidth(.expanded)
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(accent)
            Text(detail)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(FBPalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .padding(13)
        .fitnessGlass(cornerRadius: 22, tint: accent)
    }
}

struct PlanRow: View {
    let index: Int
    let workout: WorkoutPrescription
    var isCompleted = false
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.lime)
                VStack(alignment: .leading, spacing: 5) {
                    Text(workout.title)
                        .font(.system(size: 16, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text("\(workout.scheduledDate.formatted(.dateTime.weekday(.abbreviated)))  /  \(workout.exercises.count) MOVES  /  \(workout.estimatedMinutes) MIN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(FBPalette.muted)
                    Text(workout.rationale)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: isCompleted ? "checkmark.circle.fill" : (isLocked ? "lock.fill" : "arrow.up.right"))
                    .foregroundStyle(isCompleted ? FBPalette.lime : .white)
            }
            .padding(16)
            .fitnessGlass(cornerRadius: 23, tint: workout.isAIEnhanced ? FBPalette.violet : FBPalette.lime, interactive: true)
        }
        .buttonStyle(.plain)
        .disabled(isCompleted || isLocked)
        .opacity(isCompleted || isLocked ? 0.62 : 1)
    }
}

private struct ProgramBlueprintCard: View {
    let summary: ProgramSummary
    let latestDecision: AdaptationDecision?

    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionLabel(
                index: "01",
                title: "Program blueprint",
                trailing: "Week \(summary.weekNumber) / \(summary.blockLengthWeeks)"
            )

            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle().fill(FBPalette.iridescent).frame(width: 54, height: 54)
                    Image(systemName: "square.stack.3d.up.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.black)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(summary.splitName.uppercased())
                        .font(.system(size: 18, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text("\(summary.goal.shortTitle.uppercased())  /  ~\(summary.targetRIR) RIR  /  \(summary.totalWorkingSets) DIRECT SETS")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(FBPalette.lime)
                }
                Spacer()
                Button {
                    withAnimation(.snappy) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 7) {
                ForEach(summary.weeklySetsByMuscle.keys.sorted(by: { $0.rawValue < $1.rawValue }).prefix(5), id: \.self) { muscle in
                    VStack(spacing: 3) {
                        Text("\(summary.weeklySetsByMuscle[muscle, default: 0])")
                            .font(.system(size: 15, weight: .black, design: .monospaced))
                            .foregroundStyle(.white)
                        Text(muscle.rawValue.uppercased())
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(FBPalette.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    blueprintLine(icon: "person.text.rectangle", label: "WHY THIS FITS", text: summary.rationale)
                    blueprintLine(icon: "arrow.triangle.2.circlepath", label: "HOW IT PROGRESSES", text: summary.progressionRule)
                    blueprintLine(icon: "checkmark.seal.fill", label: "EVIDENCE BASIS", text: summary.evidenceNote)
                    if let latestDecision {
                        blueprintLine(
                            icon: latestDecision.direction == .increase ? "arrow.up.right" : "equal",
                            label: "LATEST DECISION / \(latestDecision.exerciseName.uppercased())",
                            text: latestDecision.reason
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .fitnessGlass(cornerRadius: 28, tint: FBPalette.violet, interactive: true)
    }

    private func blueprintLine(icon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon)
                .foregroundStyle(FBPalette.lime)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(FBPalette.muted)
                Text(text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineSpacing(2)
            }
        }
    }
}

private struct MuscleFilter: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(selected ? .black : .white)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(selected ? FBPalette.lime : Color.white.opacity(0.07), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ExerciseLibraryRow: View {
    let exercise: ExerciseDefinition

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: exercise.muscle.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(FBPalette.lime)
                .frame(width: 44, height: 44)
                .background(Color.white.opacity(0.06), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name.uppercased())
                    .font(.system(size: 13, weight: .black))
                    .fontWidth(.expanded)
                Text("\(exercise.muscle.rawValue.uppercased())  /  \(exercise.equipment.uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(FBPalette.muted)
        }
        .foregroundStyle(.white)
        .padding(14)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FBPalette.hairline, lineWidth: 0.7)
        }
    }
}

// Maintains source compatibility for previews or links from the original project.
struct WorkoutSelectionView: View {
    var body: some View { TodayView(selectedTab: .constant(.today)) }
}
