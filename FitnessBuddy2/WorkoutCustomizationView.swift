import SwiftUI

/// A private, on-device readout of the training signals already produced by
/// the deterministic program engine. Nothing in this experience requires a
/// network connection or represents itself as conversational AI.
struct InsightsView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var range: InsightRange = .sevenDays
    @State private var appeared = false

    private let recoveryMuscles: [MuscleGroup] = [.chest, .back, .legs, .shoulders]

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 24) {
                ScreenHeader(kicker: "Local training analysis", title: "Insights")
                    .padding(.top, 10)

                signalCard

                rangeControl

                HStack(spacing: 10) {
                    MetricBlock(
                        value: "\(recentSessions.count)",
                        label: "SESSIONS",
                        detail: range.shortLabel,
                        accent: FBPalette.lime
                    )
                    MetricBlock(
                        value: "\(Int(setCompletion * 100))%",
                        label: "SET COMPLETION",
                        detail: "\(completedSets) / \(totalSets)",
                        accent: FBPalette.cyan
                    )
                    MetricBlock(
                        value: FitnessFormatters.compactVolume(recentVolumeKG, units: userData.measurementSystem),
                        label: "VOLUME",
                        detail: userData.measurementSystem.weightUnit.uppercased(),
                        accent: FBPalette.magenta
                    )
                }

                adaptationSection

                recoverySection

                programSection

                localDataFooter

                Color.clear.frame(height: 104)
            }
            .padding(.horizontal, 18)
        }
        .navigationBarHidden(true)
        .sensoryFeedback(.selection, trigger: range)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.82).delay(0.08)) {
                    appeared = true
                }
            }
        }
    }

    private var signalCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 17) {
                InsightPulse(value: workoutData.readiness)
                    .frame(width: 92, height: 92)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(FBPalette.lime)
                            .frame(width: 6, height: 6)
                            .shadow(color: FBPalette.lime, radius: 5)
                        Text("ON-DEVICE / LIVE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.25)
                            .foregroundStyle(FBPalette.lime)
                    }

                    Text(signalTitle)
                        .font(.system(size: 24, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            Text(signalDetail)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                signalPill(
                    icon: "bolt.fill",
                    text: "\(Int(workoutData.readiness * 100))% READY",
                    accent: FBPalette.lime
                )
                signalPill(
                    icon: "trophy.fill",
                    text: "\(recentRecords) PR\(recentRecords == 1 ? "" : "S") / \(range.shortLabel)",
                    accent: FBPalette.magenta
                )
            }
        }
        .padding(20)
        .fitnessGlass(cornerRadius: 30, tint: FBPalette.violet)
        .scaleEffect(appeared ? 1 : 0.96)
        .opacity(appeared ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Training insight. \(signalTitle). \(signalDetail)")
    }

    private var rangeControl: some View {
        HStack(spacing: 6) {
            ForEach(InsightRange.allCases) { option in
                Button {
                    withAnimation(.snappy) { range = option }
                    FitnessHaptics.selection()
                } label: {
                    Text(option.title)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(range == option ? .black : FBPalette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            range == option ? FBPalette.lime : Color.white.opacity(0.055),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(range == option ? .isSelected : [])
            }
        }
        .padding(5)
        .background(Color.black.opacity(0.28), in: Capsule())
        .overlay { Capsule().stroke(FBPalette.hairline, lineWidth: 0.7) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Insight range")
    }

    @ViewBuilder
    private var adaptationSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(
                index: "01",
                title: "Load decisions",
                trailing: recentDecisions.isEmpty ? "Awaiting data" : "\(recentDecisions.count) signals"
            )

            if recentDecisions.isEmpty {
                emptyAdaptationCard
            } else {
                HStack(spacing: 8) {
                    decisionCount(
                        value: increaseCount,
                        label: "PROGRESS",
                        icon: "arrow.up.right",
                        accent: FBPalette.lime
                    )
                    decisionCount(
                        value: holdCount,
                        label: "HOLD",
                        icon: "equal",
                        accent: FBPalette.cyan
                    )
                    decisionCount(
                        value: reduceCount,
                        label: "RECOVER",
                        icon: "arrow.down.right",
                        accent: FBPalette.magenta
                    )
                }

                ForEach(Array(recentDecisions.prefix(4))) { decision in
                    adaptationRow(decision)
                }
            }
        }
    }

    private var emptyAdaptationCard: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.black)
                .frame(width: 46, height: 46)
                .background(FBPalette.iridescent, in: Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("BUILDING YOUR BASELINE")
                    .font(.system(size: 14, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.white)
                Text("Log every working set and report reps in reserve. Two complete top-range exposures unlock the first progression signal.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(17)
        .fitnessGlass(cornerRadius: 24, tint: FBPalette.lime)
    }

    private func adaptationRow(_ decision: AdaptationDecision) -> some View {
        let visual = decisionVisual(for: decision.direction)

        return HStack(alignment: .top, spacing: 13) {
            Image(systemName: visual.icon)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(visual.foreground)
                .frame(width: 38, height: 38)
                .background(visual.accent, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(decision.exerciseName.uppercased())
                        .font(.system(size: 12, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(decisionLoadText(decision))
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundStyle(visual.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Text(decision.reason)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineLimit(2)
                    .lineSpacing(2)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(visual.accent.opacity(0.22), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
    }

    private var recoverySection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(index: "02", title: "Recovery window", trailing: "Estimated locally")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(recoveryMuscles, id: \.self) { muscle in
                    recoveryTile(muscle)
                }
            }
        }
    }

    private func recoveryTile(_ muscle: MuscleGroup) -> some View {
        let value = workoutData.recovery(for: muscle)
        let accent = value >= 0.72 ? FBPalette.lime : (value >= 0.45 ? FBPalette.cyan : FBPalette.magenta)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: muscle.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
            }

            Text(muscle.rawValue.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(.white)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(accent)
                        .frame(width: appeared ? max(0, proxy.size.width * value) : 0)
                }
            }
            .frame(height: 6)
            .animation(.spring(response: 0.9, dampingFraction: 0.84), value: appeared)
        }
        .padding(14)
        .fitnessGlass(cornerRadius: 21, tint: accent)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(muscle.rawValue) recovery \(Int(value * 100)) percent")
    }

    @ViewBuilder
    private var programSection: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(index: "03", title: "Program logic", trailing: "Deterministic")

            if let summary = workoutData.programSummary {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 18, weight: .black))
                            .foregroundStyle(.black)
                            .frame(width: 44, height: 44)
                            .background(FBPalette.iridescent, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(summary.splitName.uppercased())
                                .font(.system(size: 16, weight: .black))
                                .fontWidth(.expanded)
                                .foregroundStyle(.white)
                            Text("WEEK \(summary.weekNumber) / \(summary.blockLengthWeeks)  ·  TARGET \(summary.targetRIR) RIR")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(FBPalette.lime)
                        }
                    }

                    Text(summary.rationale)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(FBPalette.hairline)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("PROGRESSION STANDARD")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(FBPalette.cyan)
                        Text(summary.progressionRule)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(18)
                .fitnessGlass(cornerRadius: 27, tint: FBPalette.cyan)
            }
        }
    }

    private var localDataFooter: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(FBPalette.lime)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("PRIVATE BY DESIGN")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text("These insights are calculated from your local set logs, plan, and recovery timing. No account or upload is required.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FBPalette.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .stroke(FBPalette.hairline, lineWidth: 0.7)
        }
    }

    private func signalPill(icon: String, text: String, accent: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.system(size: 8, weight: .black, design: .monospaced))
        .tracking(0.6)
        .foregroundStyle(accent)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(accent.opacity(0.09), in: Capsule())
        .overlay { Capsule().stroke(accent.opacity(0.24), lineWidth: 0.7) }
    }

    private func decisionCount(value: Int, label: String, icon: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(value)")
                    .font(.system(size: 21, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(accent)
            }
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 0.7)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label.lowercased()) decisions")
    }

    private var cutoffDate: Date {
        Calendar.autoupdatingCurrent.date(
            byAdding: .day,
            value: -(range.rawValue - 1),
            to: Calendar.autoupdatingCurrent.startOfDay(for: Date())
        ) ?? .distantPast
    }

    private var recentSessions: [WorkoutSession] {
        workoutData.completedWorkouts.filter { $0.startedAt >= cutoffDate }
    }

    private var recentDecisions: [AdaptationDecision] {
        workoutData.adaptationDecisions.filter { $0.createdAt >= cutoffDate }
    }

    private var completedSets: Int {
        recentSessions.reduce(0) { $0 + $1.completedSetCount }
    }

    private var totalSets: Int {
        recentSessions.reduce(0) { $0 + $1.totalSetCount }
    }

    private var setCompletion: Double {
        guard totalSets > 0 else { return 0 }
        return Double(completedSets) / Double(totalSets)
    }

    private var recentVolumeKG: Double {
        recentSessions.reduce(0) { $0 + $1.volume }
    }

    private var recentRecords: Int {
        workoutData.personalRecords.filter { $0.achievedAt >= cutoffDate }.count
    }

    private var increaseCount: Int {
        recentDecisions.filter { $0.direction == .increase }.count
    }

    private var holdCount: Int {
        recentDecisions.filter { $0.direction == .hold || $0.direction == .calibrate }.count
    }

    private var reduceCount: Int {
        recentDecisions.filter { $0.direction == .reduce }.count
    }

    private var signalTitle: String {
        if recentSessions.isEmpty { return "BASELINE IN PROGRESS" }
        if reduceCount > 0 { return "RECOVERY IS THE MOVE" }
        if increaseCount > 0 { return "PROGRESSION EARNED" }
        if setCompletion >= 0.9 { return "QUALITY TRENDING UP" }
        return "STAY WITH THE PLAN"
    }

    private var signalDetail: String {
        if recentSessions.isEmpty {
            return "Complete your first session to unlock load, completion, and recovery signals from your own set logs."
        }
        return workoutData.coachInsight
    }

    private func decisionVisual(
        for direction: AdaptationDirection
    ) -> (icon: String, accent: Color, foreground: Color) {
        switch direction {
        case .increase:
            ("arrow.up.right", FBPalette.lime, .black)
        case .reduce:
            ("arrow.down.right", FBPalette.magenta, .white)
        case .hold:
            ("equal", FBPalette.cyan, .black)
        case .calibrate:
            ("scope", FBPalette.violet, .white)
        }
    }

    private func decisionLoadText(_ decision: AdaptationDecision) -> String {
        guard decision.previousLoadKG > 0 || decision.nextLoadKG > 0 else {
            return decision.direction == .calibrate ? "CALIBRATE" : "BODYWEIGHT"
        }

        let previous = FitnessFormatters.weight(
            decision.previousLoadKG,
            units: userData.measurementSystem,
            includeUnit: false
        )
        let next = FitnessFormatters.weight(
            decision.nextLoadKG,
            units: userData.measurementSystem,
            includeUnit: false
        )
        return decision.previousLoadKG == decision.nextLoadKG
            ? "\(next) \(userData.measurementSystem.weightUnit.uppercased())"
            : "\(previous) → \(next) \(userData.measurementSystem.weightUnit.uppercased())"
    }
}

private enum InsightRange: Int, CaseIterable, Identifiable {
    case sevenDays = 7
    case twentyEightDays = 28

    var id: Int { rawValue }
    var title: String { self == .sevenDays ? "LAST 7 DAYS" : "LAST 28 DAYS" }
    var shortLabel: String { self == .sevenDays ? "7D" : "28D" }
}

private struct InsightPulse: View {
    let value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 7)
            Circle()
                .trim(from: 0, to: animate || reduceMotion ? value : 0.04)
                .stroke(
                    FBPalette.iridescentAngular,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            Circle()
                .fill(FBPalette.iridescent)
                .frame(width: 58, height: 58)
                .shadow(color: FBPalette.lime.opacity(0.24), radius: animate ? 16 : 8)
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 22, weight: .black))
                .foregroundStyle(.black)
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else {
                animate = true
                return
            }
            withAnimation(.spring(response: 1.0, dampingFraction: 0.78)) {
                animate = true
            }
        }
    }
}

// Retained as source-compatible wrappers for older internal navigation links.
struct CoachView: View {
    var body: some View { InsightsView() }
}

struct WorkoutCustomizationView: View {
    var body: some View { InsightsView() }
}

struct WorkoutCustomizationView_Previews: PreviewProvider {
    static var previews: some View {
        InsightsView()
            .environmentObject(UserData())
            .environmentObject(WorkoutData())
    }
}
