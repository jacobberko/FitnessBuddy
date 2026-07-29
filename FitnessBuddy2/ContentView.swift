import SwiftUI

enum FBPalette {
    static let black = Color(red: 0.015, green: 0.018, blue: 0.018)
    static let elevated = Color(red: 0.055, green: 0.06, blue: 0.065)
    static let lime = Color(red: 0.78, green: 1.0, blue: 0.20)
    static let cyan = Color(red: 0.12, green: 0.93, blue: 0.92)
    static let violet = Color(red: 0.55, green: 0.31, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.20, blue: 0.69)
    static let muted = Color.white.opacity(0.58)
    static let hairline = Color.white.opacity(0.13)

    static let iridescent = LinearGradient(
        colors: [lime, cyan, violet, magenta, lime],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let iridescentAngular = AngularGradient(
        colors: [lime, cyan, violet, magenta, lime],
        center: .center
    )
}

struct IridescentBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            FBPalette.black

            Circle()
                .fill(FBPalette.lime.opacity(0.16))
                .frame(width: 340, height: 340)
                .blur(radius: 95)
                .offset(x: animate ? 170 : -170, y: animate ? -320 : -170)

            Circle()
                .fill(FBPalette.violet.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: animate ? -150 : 160, y: animate ? 280 : 420)

            Circle()
                .fill(FBPalette.cyan.opacity(0.09))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: animate ? -120 : 130, y: 40)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, Color.black.opacity(0.15), Color.black.opacity(0.74)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 12).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

struct BrandMark: View {
    var size: CGFloat = 230
    var glow = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        Image("IridescentMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .hueRotation(.degrees(animate ? 18 : -8))
            .rotation3DEffect(.degrees(animate ? 4 : -4), axis: (x: 0.25, y: 1, z: 0))
            .scaleEffect(animate ? 1.025 : 0.985)
            .shadow(color: glow ? FBPalette.lime.opacity(0.28) : .clear, radius: 34, x: 0, y: 18)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                    animate = true
                }
            }
            .accessibilityHidden(true)
    }
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat
    var tint: Color
    var interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background(Color.white.opacity(0.025))
                .glassEffect(
                    .regular.tint(tint.opacity(0.12)).interactive(interactive),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(FBPalette.iridescent.opacity(0.24), lineWidth: 0.7)
                }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(FBPalette.iridescent.opacity(0.28), lineWidth: 0.8)
                }
        }
    }
}

extension View {
    func fitnessGlass(
        cornerRadius: CGFloat = 26,
        tint: Color = FBPalette.lime,
        interactive: Bool = false
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactive: interactive))
    }

    func editorialTitle(size: CGFloat = 44) -> some View {
        font(.system(size: size, weight: .black, design: .default))
            .fontWidth(.expanded)
            .tracking(-2.1)
    }
}

struct SectionLabel: View {
    let index: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 10) {
            Text(index)
                .foregroundStyle(FBPalette.lime)
            Text(title.uppercased())
                .foregroundStyle(.white)
            Spacer()
            if let trailing {
                Text(trailing.uppercased())
                    .foregroundStyle(FBPalette.muted)
            }
        }
        .font(.system(size: 11, weight: .bold, design: .monospaced))
        .tracking(1.25)
        .padding(.bottom, 10)
        .overlay(alignment: .bottom) {
            Rectangle().fill(FBPalette.hairline).frame(height: 1)
        }
    }
}

struct NeonActionLabel: View {
    let title: String
    var icon: String = "arrow.up.right"

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 14, weight: .black))
                .fontWidth(.expanded)
                .tracking(0.6)
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
        }
        .foregroundStyle(.black)
        .padding(.horizontal, 20)
        .frame(height: 58)
        .background(FBPalette.lime, in: Capsule())
        .shadow(color: FBPalette.lime.opacity(0.28), radius: 22, y: 8)
    }
}

struct ContentView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var watchSync: WatchSyncManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step = 0
    @State private var appeared = false
    @State private var isConnectingHealth = false
    @State private var readinessAcknowledged = false

    private let totalSteps = 9
    private let weekdays = [
        WeekdayOption(id: 1, short: "MO", title: "Monday"),
        WeekdayOption(id: 2, short: "TU", title: "Tuesday"),
        WeekdayOption(id: 3, short: "WE", title: "Wednesday"),
        WeekdayOption(id: 4, short: "TH", title: "Thursday"),
        WeekdayOption(id: 5, short: "FR", title: "Friday"),
        WeekdayOption(id: 6, short: "SA", title: "Saturday"),
        WeekdayOption(id: 7, short: "SU", title: "Sunday"),
    ]
    private let baselineExercises = [
        BaselineExercise(id: "back-squat", title: "Barbell back squat", detail: "Total bar weight", icon: "figure.strengthtraining.traditional", suggestedKG: 40),
        BaselineExercise(id: "romanian-deadlift", title: "Romanian deadlift", detail: "Total bar weight", icon: "arrow.down.to.line", suggestedKG: 40),
        BaselineExercise(id: "db-bench", title: "Dumbbell bench", detail: "Weight per dumbbell", icon: "dumbbell.fill", suggestedKG: 16),
        BaselineExercise(id: "lat-pulldown", title: "Lat pulldown", detail: "Stack weight", icon: "arrow.down", suggestedKG: 35),
        BaselineExercise(id: "shoulder-press", title: "Shoulder press", detail: "Weight per dumbbell", icon: "arrow.up", suggestedKG: 10),
    ]

    var body: some View {
        ZStack {
            IridescentBackground()

            VStack(spacing: 0) {
                onboardingHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 10)

                Group {
                    switch step {
                    case 0: heroStep
                    case 1: bodyStep
                    case 2: goalStep
                    case 3: historyStep
                    case 4: scheduleStep
                    case 5: equipmentStep
                    case 6: constraintsStep
                    case 7: baselineStep
                    default: reviewStep
                    }
                }
                .id(step)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Button(action: advance) {
                    NeonActionLabel(
                        title: step == totalSteps - 1 ? "Build my program" : "Continue",
                        icon: step == totalSteps - 1 ? "sparkles" : "arrow.right"
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canAdvance)
                .opacity(canAdvance ? 1 : 0.42)
                .sensoryFeedback(.impact(weight: .medium), trigger: step)
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.82)) {
                appeared = true
            }
        }
    }

    private var onboardingHeader: some View {
        HStack {
            Group {
                if step > 0 {
                    Button(action: goBack) {
                        HStack(spacing: 7) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .frame(height: 34)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "asterisk")
                            .font(.system(size: 16, weight: .black))
                        Text("EARNED")
                    }
                }
            }
            .font(.system(size: 12, weight: .black, design: .monospaced))

            Spacer()

            HStack(spacing: 5) {
                ForEach(0..<totalSteps, id: \.self) { item in
                    Capsule()
                        .fill(item <= step ? FBPalette.lime : Color.white.opacity(0.16))
                        .frame(width: item == step ? 22 : 7, height: 7)
                }
            }
            .animation(.snappy, value: step)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .frame(height: 46)
        .fitnessGlass(cornerRadius: 23, tint: .white)
    }

    private var heroStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                BrandMark(size: 300)
                    .offset(y: appeared ? 0 : 30)
                    .opacity(appeared ? 1 : 0)

                VStack(alignment: .leading, spacing: 12) {
                    Text("BUILT FOR\nYOUR BODY.")
                        .editorialTitle(size: 48)
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.72)

                    Text("A real training plan starts with the person—not a generic body-part list. In a few minutes, we’ll map your goal, schedule, equipment and recent performance.")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(4)

                    HStack(spacing: 9) {
                        Label("PRIVATE", systemImage: "lock.fill")
                        Text("•")
                        Text("NO ACCOUNT")
                        Text("•")
                        Text("ADULTS 18+")
                    }
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(FBPalette.lime)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var bodyStep: some View {
        OnboardingScroll(title: "START WITH\nTHE BASICS.", eyebrow: "01 / BODY + UNITS") {
            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT SHOULD WE CALL YOU?")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(FBPalette.muted)
                TextField("Name (optional)", text: $userData.name)
                    .textContentType(.name)
                    .textInputAutocapitalization(.words)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 58)
                    .fitnessGlass(cornerRadius: 22, tint: FBPalette.violet, interactive: true)
            }

            Picker("Units", selection: $userData.measurementSystem) {
                ForEach(MeasurementSystem.allCases) { system in
                    Text(system.title).tag(system)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                CompactStepperCard(
                    title: "AGE",
                    value: "\(userData.age)",
                    suffix: "YR",
                    decrement: { userData.age = max(userData.age - 1, 18) },
                    increment: { userData.age = min(userData.age + 1, 100) }
                )
                CompactStepperCard(
                    title: "HEIGHT",
                    value: heightLabel,
                    suffix: userData.measurementSystem == .imperial ? "FT / IN" : "CM",
                    decrement: { adjustHeight(by: -1) },
                    increment: { adjustHeight(by: 1) }
                )
            }

            CompactStepperCard(
                title: "BODY WEIGHT",
                value: formatted(userData.weightDisplay),
                suffix: userData.measurementSystem.weightUnit.uppercased(),
                decrement: { adjustBodyWeight(by: -1) },
                increment: { adjustBodyWeight(by: 1) }
            )

            InfoStrip(
                icon: "lock.shield.fill",
                text: "These details stay on this device and help scale a safe, realistic starting workload.",
                tint: FBPalette.cyan
            )
        }
    }

    private var goalStep: some View {
        OnboardingScroll(title: "WHAT ARE WE\nBUILDING?", eyebrow: "02 / PRIMARY GOAL") {
            ForEach(FitnessGoal.allCases) { goal in
                SelectionCard(
                    title: goal.title,
                    detail: goal.shortTitle.uppercased(),
                    icon: goal.systemImage,
                    isSelected: userData.goal == goal
                ) {
                    withAnimation(.snappy) { userData.goal = goal }
                }
            }
        }
    }

    private var historyStep: some View {
        OnboardingScroll(title: "MEET YOU\nWHERE YOU ARE.", eyebrow: "03 / TRAINING HISTORY") {
            ForEach(FitnessExperience.allCases) { experience in
                SelectionCard(
                    title: experience.title,
                    detail: experience.detail,
                    icon: experience == .beginner ? "figure.walk" : (experience == .intermediate ? "figure.run" : "bolt.fill"),
                    isSelected: userData.experience == experience
                ) {
                    withAnimation(.snappy) {
                        userData.experience = experience
                        userData.trainingAgeMonths = defaultTrainingAge(for: experience)
                    }
                }
            }

            CompactStepperCard(
                title: "CONSISTENT TRAINING",
                value: trainingAgeLabel,
                suffix: "TOTAL",
                decrement: { adjustTrainingAge(increasing: false) },
                increment: { adjustTrainingAge(increasing: true) }
            )

            VStack(alignment: .leading, spacing: 13) {
                Text("USUAL RECOVERY BETWEEN SESSIONS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(FBPalette.muted)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            userData.recoveryRating = rating
                        } label: {
                            VStack(spacing: 5) {
                                Text("\(rating)")
                                    .font(.system(size: 18, weight: .black))
                                Text(recoveryWord(for: rating))
                                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(userData.recoveryRating == rating ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(userData.recoveryRating == rating ? FBPalette.lime : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 17))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Recovery \(rating) of 5, \(recoveryWord(for: rating))")
                    }
                }
                Text("A simple self-rating—not a medical assessment. It sets how aggressively your first week should progress.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineSpacing(2)
            }
            .padding(17)
            .fitnessGlass(cornerRadius: 24, tint: FBPalette.cyan)
        }
    }

    private var scheduleStep: some View {
        OnboardingScroll(title: "MAKE IT FIT\nREAL LIFE.", eyebrow: "04 / REAL SCHEDULE") {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("TRAINING DAYS")
                        Spacer()
                        Text("\(userData.preferredWeekdays.count)× / WEEK")
                            .foregroundStyle(FBPalette.lime)
                    }
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(FBPalette.muted)

                    HStack(spacing: 6) {
                        ForEach(weekdays) { weekday in
                            weekdayButton(weekday)
                        }
                    }

                    Text("Choose 2–6 days you can repeat most weeks. The plan will place recovery between harder sessions when possible.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(2)
                }
                .padding(18)
                .fitnessGlass(cornerRadius: 26, tint: FBPalette.violet)

                ScheduleControl(
                    value: $userData.sessionMinutes,
                    range: 30...90,
                    step: 5,
                    title: "MINUTES / SESSION",
                    valueSuffix: "MIN"
                )

                HStack(spacing: 12) {
                    Image(systemName: "wand.and.sparkles")
                        .foregroundStyle(FBPalette.lime)
                    Text("Your available time limits exercise count before quality. Every programmed session is built to fit this window.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                }
                .padding(18)
                .fitnessGlass(cornerRadius: 22, tint: FBPalette.violet)
            }
        }
    }

    private var equipmentStep: some View {
        OnboardingScroll(title: "WHAT CAN YOU\nTRAIN WITH?", eyebrow: "05 / EQUIPMENT") {
            HStack(spacing: 9) {
                PresetChip(title: "FULL GYM", isSelected: userData.equipment.count == EquipmentOption.allCases.count) {
                    userData.equipment = Set(EquipmentOption.allCases)
                }
                PresetChip(title: "HOME KIT", isSelected: userData.equipment == [.dumbbells, .resistanceBands, .bodyweight]) {
                    userData.equipment = [.dumbbells, .resistanceBands, .bodyweight]
                }
                PresetChip(title: "NO GEAR", isSelected: userData.equipment == [.bodyweight]) {
                    userData.equipment = [.bodyweight]
                }
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                ForEach(EquipmentOption.allCases) { option in
                    EquipmentCard(option: option, isSelected: userData.equipment.contains(option)) {
                        toggleEquipment(option)
                    }
                }
            }

            InfoStrip(
                icon: "arrow.triangle.branch",
                text: "Exercise selection is filtered to what you actually have. You can change this later and rebuild the week.",
                tint: FBPalette.violet
            )
        }
    }

    private var constraintsStep: some View {
        OnboardingScroll(title: "MOVEMENT,\nON YOUR TERMS.", eyebrow: "06 / PREFERENCES + LIMITS") {
            SelectionCard(
                title: "No current movement limits",
                detail: "PROGRAM FROM THE FULL EXERCISE LIBRARY",
                icon: "checkmark.shield.fill",
                isSelected: userData.constraints.isEmpty
            ) {
                withAnimation(.snappy) { userData.constraints = [] }
            }

            ForEach(TrainingConstraint.allCases) { constraint in
                SelectionCard(
                    title: constraint.title,
                    detail: constraint.detail,
                    icon: constraint.systemImage,
                    isSelected: userData.constraints.contains(constraint)
                ) {
                    withAnimation(.snappy) { toggleConstraint(constraint) }
                }
            }

            InfoStrip(
                icon: "cross.case.fill",
                text: "Use these only for movements you already know you prefer to limit. This does not diagnose or treat an injury; a qualified professional should guide pain or medical concerns.",
                tint: FBPalette.magenta
            )
        }
    }

    private var baselineStep: some View {
        OnboardingScroll(title: "GIVE US A\nSTARTING SIGNAL.", eyebrow: "07 / OPTIONAL WORKING SETS") {
            InfoStrip(
                icon: "chart.line.uptrend.xyaxis",
                text: "Add a recent, comfortable working set—not a true max. Weight + reps + reps in reserve (RIR) lets us estimate a conservative starting load. Skip anything you don't perform.",
                tint: FBPalette.lime
            )

            ForEach(availableBaselineExercises) { exercise in
                BaselineEntryCard(exercise: exercise)
                    .environmentObject(userData)
            }

            if availableBaselineExercises.isEmpty {
                InfoStrip(
                    icon: "checkmark.circle.fill",
                    text: "Your selected setup does not need a numeric starting load. The first workouts will progress from reps, RIR, band tension, and exercise variation.",
                    tint: FBPalette.cyan
                )
            }

            if !userData.baselines.isEmpty {
                Button {
                    availableBaselineExercises.forEach { userData.removeBaseline(exerciseID: $0.id) }
                } label: {
                    Label("CLEAR THESE + SKIP", systemImage: "xmark")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(FBPalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reviewStep: some View {
        OnboardingScroll(title: "YOUR FIRST\nTRAINING BLOCK.", eyebrow: "08 / REVIEW + CONNECT") {
            VStack(alignment: .leading, spacing: 17) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(programSplit.uppercased())
                            .font(.system(size: 18, weight: .black))
                            .fontWidth(.expanded)
                        Text("\(userData.sessionsPerWeek) DAYS  /  \(userData.sessionMinutes) MIN")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(FBPalette.lime)
                    }
                    Spacer()
                    Image(systemName: userData.goal.systemImage)
                        .font(.system(size: 25, weight: .black))
                        .foregroundStyle(.black)
                        .frame(width: 52, height: 52)
                        .background(FBPalette.iridescent, in: Circle())
                }

                Rectangle().fill(FBPalette.hairline).frame(height: 1)

                ReviewLine(icon: "calendar", title: "TRAINING DAYS", value: selectedWeekdayLabel)
                ReviewLine(icon: "square.stack.3d.up.fill", title: "STARTING DOSE", value: startingDose)
                ReviewLine(icon: "gauge.with.dots.needle.50percent", title: "EFFORT TARGET", value: targetRIRLabel)
                ReviewLine(icon: "chart.bar.fill", title: "LOAD SIGNALS", value: userData.baselines.isEmpty ? "Conservative defaults" : "\(userData.baselines.count) working sets")
                ReviewLine(icon: "dumbbell.fill", title: "AVAILABLE GEAR", value: "\(userData.equipment.count) selected")
            }
            .foregroundStyle(.white)
            .padding(20)
            .fitnessGlass(cornerRadius: 28, tint: FBPalette.lime)

            Button {
                connectHealth()
            } label: {
                HStack(spacing: 15) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 21, weight: .bold))
                        .foregroundStyle(.red)
                        .frame(width: 46, height: 46)
                        .background(Color.white.opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("APPLE HEALTH")
                            .font(.system(size: 13, weight: .black, design: .monospaced))
                        Text(healthConnectionLabel)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FBPalette.muted)
                    }
                    Spacer()
                    if isConnectingHealth {
                        ProgressView().tint(FBPalette.lime)
                    } else {
                        Image(systemName: healthKit.status == .authorized ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundStyle(healthKit.status == .authorized ? FBPalette.lime : .white)
                    }
                }
                .foregroundStyle(.white)
                .padding(14)
                .fitnessGlass(cornerRadius: 24, tint: .red, interactive: true)
            }
            .buttonStyle(.plain)
            .disabled(isConnectingHealth || healthKit.status == .unavailable || healthKit.status == .authorized)

            Button {
                readinessAcknowledged.toggle()
            } label: {
                HStack(alignment: .top, spacing: 13) {
                    Image(systemName: readinessAcknowledged ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(readinessAcknowledged ? FBPalette.lime : Color.white.opacity(0.45))
                    Text("I understand this is training guidance, not medical care. I’ll start conservatively, use movements I can perform comfortably, and stop if something feels wrong.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(3)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(17)
                .fitnessGlass(cornerRadius: 22, tint: readinessAcknowledged ? FBPalette.lime : .white, interactive: true)
            }
            .buttonStyle(.plain)

            InfoStrip(
                icon: "arrow.triangle.2.circlepath",
                text: "After each workout, completed reps, load and effort inform the next prescription. Your plan raises, holds or reduces work instead of blindly adding weight.",
                tint: FBPalette.cyan
            )
        }
    }

    private var canAdvance: Bool {
        if step == 5 { return !userData.equipment.isEmpty }
        if step == totalSteps - 1 { return readinessAcknowledged && !isConnectingHealth }
        return true
    }

    private var heightLabel: String {
        if userData.measurementSystem == .metric {
            return "\(Int(userData.heightCM.rounded()))"
        }
        let totalInches = Int((userData.heightCM / 2.54).rounded())
        return "\(totalInches / 12)′ \(totalInches % 12)″"
    }

    private var trainingAgeLabel: String {
        let months = userData.trainingAgeMonths
        if months < 12 { return "\(months) MO" }
        let years = months / 12
        let remainder = months % 12
        return remainder == 0 ? "\(years) YR" : "\(years)Y \(remainder)M"
    }

    private var programSplit: String {
        switch userData.sessionsPerWeek {
        case 2: "Full body A / B"
        case 3: "Full-body rotation"
        case 4: "Upper / lower split"
        case 5: "Upper / lower + focus"
        default: "Push / pull / legs"
        }
    }

    private var startingDose: String {
        switch userData.goal {
        case .strength: "2–3 sets • priority lifts first"
        case .muscle: "~8–10 weekly sets / muscle"
        case .generalFitness: "2–3 sets • balanced patterns"
        case .athleticPerformance: "Strength + movement quality"
        }
    }

    private var targetRIRLabel: String {
        switch userData.experience {
        case .beginner: "About 3 reps in reserve"
        case .intermediate: "About 2 reps in reserve"
        case .advanced: "1–2 reps in reserve"
        }
    }

    private var selectedWeekdayLabel: String {
        weekdays
            .filter { userData.preferredWeekdays.contains($0.id) }
            .map(\.short)
            .joined(separator: " · ")
    }

    private var healthConnectionLabel: String {
        switch healthKit.status {
        case .unavailable: "Unavailable on this device"
        case .notRequested: "Optional • sync completed workouts"
        case .authorized: "Connected"
        case .needsSettings: "Review access in Settings"
        }
    }

    private var availableBaselineExercises: [BaselineExercise] {
        baselineExercises.filter { exercise in
            switch exercise.id {
            case "back-squat", "romanian-deadlift":
                userData.equipment.contains(.barbellRack)
            case "db-bench":
                userData.equipment.contains(.dumbbells) && userData.equipment.contains(.bench)
            case "lat-pulldown":
                userData.equipment.contains(.cables)
            case "shoulder-press":
                userData.equipment.contains(.dumbbells)
            default:
                false
            }
        }
    }

    @ViewBuilder
    private func weekdayButton(_ weekday: WeekdayOption) -> some View {
        let selected = userData.preferredWeekdays.contains(weekday.id)
        Button {
            toggleWeekday(weekday.id)
        } label: {
            Text(weekday.short)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(selected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(selected ? FBPalette.lime : Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.85)) {
                step += 1
            }
        } else {
            normalizeInputs()
            workoutData.configure(for: userData.snapshot, force: true)
            watchSync.sync(plan: workoutData.weeklyPlan)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.84)) {
                userData.completeOnboarding()
            }
        }
    }

    private func goBack() {
        guard step > 0 else { return }
        withAnimation(reduceMotion ? .none : .spring(response: 0.48, dampingFraction: 0.85)) {
            step -= 1
        }
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }

    private func adjustHeight(by increment: Int) {
        if userData.measurementSystem == .imperial {
            let inches = min(max(Int((userData.heightCM / 2.54).rounded()) + increment, 48), 90)
            userData.heightCM = Double(inches) * 2.54
        } else {
            userData.heightCM = min(max(userData.heightCM + Double(increment), 120), 230)
        }
    }

    private func adjustBodyWeight(by increment: Double) {
        let lower = userData.measurementSystem == .imperial ? 66.0 : 30.0
        let upper = userData.measurementSystem == .imperial ? 660.0 : 300.0
        userData.setDisplayedWeight(min(max(userData.weightDisplay + increment, lower), upper))
    }

    private func defaultTrainingAge(for experience: FitnessExperience) -> Int {
        switch experience {
        case .beginner: 3
        case .intermediate: 18
        case .advanced: 48
        }
    }

    private func adjustTrainingAge(increasing: Bool) {
        let current = userData.trainingAgeMonths
        let increment = current < 24 ? 1 : (current < 60 ? 3 : 6)
        userData.trainingAgeMonths = min(max(current + (increasing ? increment : -increment), 0), 600)
    }

    private func recoveryWord(for rating: Int) -> String {
        switch rating {
        case 1: "LOW"
        case 2: "VAR."
        case 3: "OK"
        case 4: "GOOD"
        default: "HIGH"
        }
    }

    private func toggleWeekday(_ day: Int) {
        if userData.preferredWeekdays.contains(day) {
            guard userData.preferredWeekdays.count > 2 else { return }
            userData.preferredWeekdays.remove(day)
        } else {
            guard userData.preferredWeekdays.count < 6 else { return }
            userData.preferredWeekdays.insert(day)
        }
        userData.sessionsPerWeek = userData.preferredWeekdays.count
    }

    private func toggleEquipment(_ option: EquipmentOption) {
        if userData.equipment.contains(option) {
            if userData.equipment.count == 1 {
                userData.equipment = [.bodyweight]
            } else {
                userData.equipment.remove(option)
            }
        } else {
            userData.equipment.insert(option)
        }
    }

    private func toggleConstraint(_ constraint: TrainingConstraint) {
        if userData.constraints.contains(constraint) {
            userData.constraints.remove(constraint)
        } else {
            userData.constraints.insert(constraint)
        }
    }

    private func connectHealth() {
        Task {
            isConnectingHealth = true
            let connected = await healthKit.requestAuthorization()
            userData.healthKitEnabled = connected
            isConnectingHealth = false
        }
    }

    private func normalizeInputs() {
        userData.age = min(max(userData.age, 18), 100)
        userData.heightCM = min(max(userData.heightCM, 120), 230)
        userData.weightKG = min(max(userData.weightKG, 30), 300)
        userData.trainingAgeMonths = min(max(userData.trainingAgeMonths, 0), 600)
        userData.recoveryRating = min(max(userData.recoveryRating, 1), 5)
        userData.name = userData.name.trimmingCharacters(in: .whitespacesAndNewlines)

        let validDays = userData.preferredWeekdays.filter { (1...7).contains($0) }
        if validDays.count >= 2 {
            userData.preferredWeekdays = Set(validDays.sorted().prefix(6))
        } else {
            userData.preferredWeekdays = [1, 3, 5, 6]
        }
        userData.sessionsPerWeek = userData.preferredWeekdays.count
        if userData.equipment.isEmpty { userData.equipment = [.bodyweight] }
    }
}

private struct WeekdayOption: Identifiable {
    let id: Int
    let short: String
    let title: String
}

private struct BaselineExercise: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let suggestedKG: Double
}

private struct CompactStepperCard: View {
    let title: String
    let value: String
    let suffix: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text(title)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(0.9)
                .foregroundStyle(FBPalette.muted)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 27, weight: .black))
                    .fontWidth(.expanded)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text(suffix)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .foregroundStyle(FBPalette.lime)
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                adjustButton(icon: "minus", action: decrement, filled: false)
                adjustButton(icon: "plus", action: increment, filled: true)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(17)
        .fitnessGlass(cornerRadius: 24, tint: FBPalette.cyan)
    }

    private func adjustButton(icon: String, action: @escaping () -> Void, filled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(filled ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(filled ? FBPalette.lime : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct InfoStrip: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FBPalette.muted)
                .lineSpacing(3)
            Spacer(minLength: 0)
        }
        .padding(17)
        .fitnessGlass(cornerRadius: 22, tint: tint)
    }
}

private struct PresetChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(isSelected ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 39)
                .background(isSelected ? FBPalette.lime : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct EquipmentCard: View {
    let option: EquipmentOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 11) {
                HStack {
                    Image(systemName: option.systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(isSelected ? .black : FBPalette.lime)
                        .frame(width: 39, height: 39)
                        .background(isSelected ? FBPalette.lime : Color.white.opacity(0.07), in: Circle())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? FBPalette.lime : Color.white.opacity(0.25))
                }
                Text(option.title.uppercased())
                    .font(.system(size: 11, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(option.detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 118, alignment: .top)
            .padding(14)
            .contentShape(Rectangle())
            .fitnessGlass(cornerRadius: 22, tint: isSelected ? FBPalette.lime : .white, interactive: true)
        }
        .buttonStyle(.plain)
    }
}

private struct BaselineEntryCard: View {
    @EnvironmentObject private var userData: UserData
    let exercise: BaselineExercise

    private var baseline: LiftBaseline? {
        userData.baseline(for: exercise.id)
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 14) {
                    Image(systemName: exercise.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(baseline == nil ? FBPalette.lime : .black)
                        .frame(width: 43, height: 43)
                        .background(baseline == nil ? Color.white.opacity(0.07) : FBPalette.lime, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.title.uppercased())
                            .font(.system(size: 13, weight: .black))
                            .fontWidth(.expanded)
                            .foregroundStyle(.white)
                        Text(exercise.detail)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(FBPalette.muted)
                    }
                    Spacer()
                    Text(baseline == nil ? "ADD" : "ADDED")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .foregroundStyle(baseline == nil ? FBPalette.muted : FBPalette.lime)
                    Image(systemName: baseline == nil ? "plus.circle" : "checkmark.circle.fill")
                        .foregroundStyle(baseline == nil ? .white : FBPalette.lime)
                }
                .contentShape(Rectangle())
                .padding(15)
            }
            .buttonStyle(.plain)

            if let baseline {
                Rectangle().fill(FBPalette.hairline).frame(height: 1)
                    .padding(.horizontal, 15)

                HStack(spacing: 8) {
                    BaselineAdjuster(
                        title: "WEIGHT",
                        value: formatted(userData.displayWeight(kg: baseline.weightKG)),
                        suffix: userData.measurementSystem.weightUnit.uppercased(),
                        decrement: { adjustWeight(by: -weightStep) },
                        increment: { adjustWeight(by: weightStep) }
                    )
                    BaselineAdjuster(
                        title: "REPS",
                        value: "\(baseline.reps)",
                        suffix: "REPS",
                        decrement: { update(reps: max(baseline.reps - 1, 1)) },
                        increment: { update(reps: min(baseline.reps + 1, 12)) }
                    )
                    BaselineAdjuster(
                        title: "RIR",
                        value: "\(baseline.rir ?? 2)",
                        suffix: "LEFT",
                        decrement: { update(rir: max((baseline.rir ?? 2) - 1, 0)) },
                        increment: { update(rir: min((baseline.rir ?? 2) + 1, 5)) }
                    )
                }
                .padding(12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .fitnessGlass(cornerRadius: 24, tint: baseline == nil ? .white : FBPalette.lime)
        .animation(.snappy, value: baseline != nil)
    }

    private var weightStep: Double {
        userData.measurementSystem == .imperial ? 5 : 2.5
    }

    private func toggle() {
        if baseline != nil {
            userData.removeBaseline(exerciseID: exercise.id)
        } else {
            let display = userData.displayWeight(kg: exercise.suggestedKG)
            userData.setBaseline(exerciseID: exercise.id, displayWeight: display, reps: 8, rir: 2)
        }
    }

    private func adjustWeight(by delta: Double) {
        guard let baseline else { return }
        let current = userData.displayWeight(kg: baseline.weightKG)
        update(displayWeight: max(current + delta, weightStep))
    }

    private func update(displayWeight: Double? = nil, reps: Int? = nil, rir: Int? = nil) {
        guard let baseline else { return }
        userData.setBaseline(
            exerciseID: exercise.id,
            displayWeight: displayWeight ?? userData.displayWeight(kg: baseline.weightKG),
            reps: reps ?? baseline.reps,
            rir: rir ?? baseline.rir
        )
    }

    private func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}

private struct BaselineAdjuster: View {
    let title: String
    let value: String
    let suffix: String
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 7, weight: .black, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(FBPalette.muted)
            Text(value)
                .font(.system(size: 19, weight: .black))
                .fontWidth(.expanded)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(suffix)
                .font(.system(size: 6, weight: .black, design: .monospaced))
                .foregroundStyle(FBPalette.lime)
            HStack(spacing: 5) {
                smallButton(icon: "minus", action: decrement, filled: false)
                smallButton(icon: "plus", action: increment, filled: true)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 17))
    }

    private func smallButton(icon: String, action: @escaping () -> Void, filled: Bool) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(filled ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 28)
                .background(filled ? FBPalette.lime : Color.white.opacity(0.08), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct ReviewLine: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FBPalette.lime)
                .frame(width: 21)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 8, weight: .black, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(FBPalette.muted)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct OnboardingScroll<Content: View>: View {
    let title: String
    let eyebrow: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(eyebrow)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(FBPalette.lime)
                    Text(title)
                        .editorialTitle(size: 42)
                        .foregroundStyle(.white)
                }
                .padding(.top, 42)

                VStack(spacing: 12) { content }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}

private struct SelectionCard: View {
    let title: String
    let detail: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? .black : FBPalette.lime)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? FBPalette.lime : Color.white.opacity(0.07), in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text(title.uppercased())
                        .font(.system(size: 16, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? FBPalette.lime : Color.white.opacity(0.25))
                    .font(.title3)
            }
            .padding(16)
            .contentShape(Rectangle())
            .fitnessGlass(cornerRadius: 24, tint: isSelected ? FBPalette.lime : .white, interactive: true)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

private struct ScheduleControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let title: String
    let valueSuffix: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(FBPalette.muted)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(value)")
                        .font(.system(size: 43, weight: .black))
                        .fontWidth(.expanded)
                    Text(valueSuffix)
                        .font(.system(size: 12, weight: .black, design: .monospaced))
                        .foregroundStyle(FBPalette.lime)
                }
            }
            Spacer()
            HStack(spacing: 10) {
                stepButton(icon: "minus", delta: -step)
                stepButton(icon: "plus", delta: step)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .fitnessGlass(cornerRadius: 26, tint: FBPalette.cyan)
    }

    private func stepButton(icon: String, delta: Int) -> some View {
        Button {
            value = min(max(value + delta, range.lowerBound), range.upperBound)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .black))
                .frame(width: 46, height: 46)
                .foregroundStyle(delta > 0 ? .black : .white)
                .background(delta > 0 ? FBPalette.lime : Color.white.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UserData())
            .environmentObject(WorkoutData())
            .environmentObject(HealthKitManager())
            .environmentObject(WatchSyncManager())
    }
}
