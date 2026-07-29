import SwiftUI
import WatchConnectivity

struct YouView: View {
    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @EnvironmentObject private var healthKit: HealthKitManager
    @EnvironmentObject private var watchSync: WatchSyncManager

    @State private var isConnectingHealth = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 28) {
                ScreenHeader(kicker: "Local profile / private", title: "You")
                    .padding(.top, 10)

                identityCard
                trainingProfile
                measurementProfile
                integrations
                trainingIntelligence
                privacyCard
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 118)
        }
        .navigationBarHidden(true)
    }

    private var identityCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(FBPalette.iridescent).frame(width: 70, height: 70)
                Text(userData.firstName.prefix(1).uppercased())
                    .font(.system(size: 27, weight: .black))
                    .foregroundStyle(.black)
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Your name", text: $userData.name)
                    .font(.system(size: 22, weight: .black))
                    .fontWidth(.expanded)
                    .foregroundStyle(.white)
                Text("\(userData.experience.title.uppercased())  /  \(userData.goal.shortTitle.uppercased())")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(FBPalette.lime)
            }
            Spacer()
        }
        .padding(18)
        .fitnessGlass(cornerRadius: 28, tint: FBPalette.violet)
    }

    private var trainingProfile: some View {
        VStack(alignment: .leading, spacing: 15) {
            SectionLabel(index: "01", title: "Training profile", trailing: "Adaptive inputs")

            SettingsPickerRow(title: "EXPERIENCE", icon: "bolt.fill") {
                Picker("Experience", selection: $userData.experience) {
                    ForEach(FitnessExperience.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .tint(FBPalette.lime)
            }

            SettingsPickerRow(title: "PRIMARY GOAL", icon: userData.goal.systemImage) {
                Picker("Goal", selection: $userData.goal) {
                    ForEach(FitnessGoal.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .tint(FBPalette.lime)
            }

            ValueStepperRow(title: "DAYS / WEEK", value: sessionsPerWeekBinding, range: 2...6, suffix: "×")
            ValueStepperRow(title: "SESSION LENGTH", value: $userData.sessionMinutes, range: 30...90, step: 5, suffix: "MIN")

            Button {
                workoutData.configure(for: userData.snapshot, force: true)
                watchSync.sync(plan: workoutData.weeklyPlan)
                FitnessHaptics.personalRecord()
            } label: {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("REBUILD WEEK FROM PROFILE")
                    Spacer()
                    Image(systemName: "sparkles")
                }
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 15)
                .frame(height: 48)
                .background(FBPalette.lime, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var measurementProfile: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(index: "02", title: "Body & units", trailing: "Stored locally")

            Picker("Units", selection: $userData.measurementSystem) {
                ForEach(MeasurementSystem.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                NumberFieldCard(title: "AGE", value: Binding(
                    get: { Double(userData.age) },
                    set: { userData.age = min(max(Int($0), 18), 100) }
                ), suffix: "YR", decimal: false)
                NumberFieldCard(title: "WEIGHT", value: Binding(
                    get: { userData.weightDisplay },
                    set: { userData.setDisplayedWeight($0) }
                ), suffix: userData.measurementSystem.weightUnit.uppercased(), decimal: true)
            }
        }
    }

    private var integrations: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(index: "03", title: "Apple ecosystem", trailing: "Sync")

            IntegrationCard(
                icon: "heart.fill",
                color: .red,
                title: "APPLE HEALTH",
                detail: healthKit.status.label.uppercased(),
                status: healthKit.status == .authorized
            ) {
                Task {
                    isConnectingHealth = true
                    let success = await healthKit.requestAuthorization()
                    userData.healthKitEnabled = success
                    isConnectingHealth = false
                }
            }
            .disabled(isConnectingHealth)

            IntegrationCard(
                icon: "applewatch",
                color: FBPalette.cyan,
                title: "APPLE WATCH",
                detail: watchStatus,
                status: watchSync.activationState == .activated
            ) {
                watchSync.sync(plan: workoutData.weeklyPlan)
                FitnessHaptics.selection()
            }

            IntegrationCard(
                icon: "livephoto",
                color: FBPalette.magenta,
                title: "LIVE ACTIVITIES",
                detail: "STARTS WITH ACTIVE WORKOUTS",
                status: true
            ) { FitnessHaptics.selection() }
        }
    }

    private var trainingIntelligence: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionLabel(index: "04", title: "Training intelligence", trailing: "On device")

            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(FBPalette.lime)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    Text("LOCAL ADAPTATION")
                        .font(.system(size: 13, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text("Your week is built from your goal, experience, schedule, equipment, movement limits, and starting lifts. Completed reps, loads, and reps in reserve guide later progression. The process runs on this device and does not contact an AI service.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .fitnessGlass(cornerRadius: 24, tint: FBPalette.violet)
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(index: "05", title: "Privacy", trailing: "No account")
            HStack(alignment: .top, spacing: 13) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(FBPalette.lime)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 5) {
                    Text("LOCAL-FIRST BY DESIGN")
                        .font(.system(size: 13, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text("Your profile, plan, set logs, and PRs stay in the app's private storage. There is no account, analytics, advertising, or developer server. With your permission, Apple Health supplies recent workout history and receives completed workouts; paired-device sync uses Apple Watch Connectivity. Plan generation and weekly adaptation run locally.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .fitnessGlass(cornerRadius: 24, tint: FBPalette.lime)

            HStack(spacing: 10) {
                legalResourceLink(
                    title: "PRIVACY POLICY",
                    icon: "hand.raised.fill",
                    destination: "https://jacobberko.com/fitness/privacy/"
                )
                legalResourceLink(
                    title: "SUPPORT",
                    icon: "questionmark.circle.fill",
                    destination: "https://jacobberko.com/fitness/support/"
                )
            }

            Button("RUN ONBOARDING AGAIN") { userData.resetOnboarding() }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(FBPalette.muted)
                .padding(.top, 5)
        }
    }

    @ViewBuilder
    private func legalResourceLink(title: String, icon: String, destination: String) -> some View {
        if let url = URL(string: destination) {
            Link(destination: url) {
                HStack(spacing: 7) {
                    Image(systemName: icon)
                    Text(title)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .frame(maxWidth: .infinity)
                .frame(height: 43)
                .background(Color.white.opacity(0.055), in: Capsule())
                .overlay {
                    Capsule()
                        .stroke(FBPalette.hairline, lineWidth: 0.7)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens in your web browser")
        }
    }

    private var watchStatus: String {
        switch watchSync.activationState {
        case .activated: watchSync.isReachable ? "CONNECTED / REACHABLE" : "PAIRED / BACKGROUND SYNC"
        case .inactive: "INACTIVE"
        case .notActivated: "ACTIVATING"
        @unknown default: "UNKNOWN"
        }
    }

    private var sessionsPerWeekBinding: Binding<Int> {
        Binding(
            get: { userData.sessionsPerWeek },
            set: { requestedCount in
                let count = min(max(requestedCount, 2), 6)
                let weekdays: Set<Int>

                switch count {
                case 2: weekdays = [2, 5]
                case 3: weekdays = [1, 3, 5]
                case 4: weekdays = [1, 2, 4, 5]
                case 5: weekdays = [1, 2, 3, 5, 6]
                default: weekdays = [1, 2, 3, 4, 5, 6]
                }

                userData.preferredWeekdays = weekdays
                userData.sessionsPerWeek = weekdays.count
            }
        )
    }
}

private struct SettingsPickerRow<Control: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(FBPalette.lime)
                .frame(width: 24)
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            control
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(FBPalette.hairline, lineWidth: 0.7) }
    }
}

private struct ValueStepperRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let suffix: String

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            Spacer()
            Button { value = max(value - step, range.lowerBound) } label: {
                Image(systemName: "minus").frame(width: 35, height: 35)
            }
            Text("\(value) \(suffix)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(FBPalette.lime)
                .frame(width: 68)
            Button { value = min(value + step, range.upperBound) } label: {
                Image(systemName: "plus").frame(width: 35, height: 35)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).stroke(FBPalette.hairline, lineWidth: 0.7) }
    }
}

private struct NumberFieldCard: View {
    let title: String
    @Binding var value: Double
    let suffix: String
    let decimal: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(FBPalette.lime)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                TextField("0", value: $value, format: .number.precision(.fractionLength(decimal ? 0...1 : 0...0)))
                    .keyboardType(decimal ? .decimalPad : .numberPad)
                    .font(.system(size: 25, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                Text(suffix)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(FBPalette.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .fitnessGlass(cornerRadius: 22, tint: FBPalette.cyan)
    }
}

private struct IntegrationCard: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String
    let status: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 43, height: 43)
                    .background(Color.white.opacity(0.065), in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 12, weight: .black))
                        .fontWidth(.expanded)
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(FBPalette.muted)
                }
                Spacer()
                Circle()
                    .fill(status ? FBPalette.lime : Color.white.opacity(0.16))
                    .frame(width: 9, height: 9)
            }
            .padding(13)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
            .overlay { RoundedRectangle(cornerRadius: 20).stroke(FBPalette.hairline, lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
    }
}

// The original profile screen name now routes into the rebuilt account-free profile.
struct UserInputView: View {
    var body: some View { YouView() }
}
