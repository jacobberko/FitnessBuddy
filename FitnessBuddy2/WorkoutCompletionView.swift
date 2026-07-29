import SwiftUI

struct WorkoutCompletionView: View {
    let session: WorkoutSession
    let onDone: () -> Void

    @EnvironmentObject private var userData: UserData
    @EnvironmentObject private var workoutData: WorkoutData
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var reveal = false
    @State private var burst = false

    private var sessionPRs: [PersonalRecord] {
        workoutData.personalRecords.filter { $0.sessionID == session.id }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(FBPalette.lime.opacity(0.2))
                        .frame(width: 220, height: 220)
                        .blur(radius: 55)
                    BrandMark(size: 215)
                        .scaleEffect(reveal ? 1 : 0.5)
                        .rotationEffect(.degrees(reveal ? 0 : -22))
                }
                .frame(height: 235)
                .overlay { ConfettiBurst(animate: burst).allowsHitTesting(false) }

                VStack(spacing: 9) {
                    Text("SESSION / COMPLETE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(FBPalette.lime)
                    Text("WORK\nBANKED.")
                        .editorialTitle(size: 50)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Every logged set just made your next week smarter.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FBPalette.muted)
                        .multilineTextAlignment(.center)
                }
                .offset(y: reveal ? 0 : 20)
                .opacity(reveal ? 1 : 0)

                HStack(spacing: 10) {
                    summary(value: "\(session.completedSetCount)", label: "SETS")
                    summary(value: FitnessFormatters.duration(session.duration), label: "TIME")
                    summary(value: FitnessFormatters.compactVolume(session.volume, units: userData.measurementSystem), label: "VOLUME")
                }
                .offset(y: reveal ? 0 : 22)
                .opacity(reveal ? 1 : 0)

                if !sessionPRs.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel(index: "PR", title: "New records", trailing: "\(sessionPRs.count)")
                        ForEach(sessionPRs.prefix(3)) { record in
                            HStack {
                                Image(systemName: "trophy.fill")
                                    .foregroundStyle(.black)
                                    .frame(width: 40, height: 40)
                                    .background(FBPalette.iridescent, in: Circle())
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.exerciseName.uppercased())
                                        .font(.system(size: 12, weight: .black))
                                        .fontWidth(.expanded)
                                    Text("\(FitnessFormatters.weight(record.valueKG, units: userData.measurementSystem)) × \(record.reps)")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(FBPalette.lime)
                                }
                                Spacer()
                            }
                            .foregroundStyle(.white)
                        }
                    }
                    .padding(18)
                    .fitnessGlass(cornerRadius: 26, tint: FBPalette.magenta)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button(action: onDone) {
                    NeonActionLabel(title: "Save and finish", icon: "checkmark")
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(FBPalette.black.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 40, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 40, style: .continuous)
                .stroke(FBPalette.iridescent.opacity(0.46), lineWidth: 1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 18)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.72)) {
                reveal = true
            }
            if !reduceMotion {
                withAnimation(.easeOut(duration: 1.45)) { burst = true }
            }
        }
    }

    private func summary(value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: 21, weight: .black, design: .monospaced))
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(FBPalette.lime)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 75)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ConfettiBurst: View {
    let animate: Bool

    var body: some View {
        ZStack {
            ForEach(0..<46, id: \.self) { index in
                ConfettiParticle(index: index, animate: animate)
            }
        }
    }
}

private struct ConfettiParticle: View {
    let index: Int
    let animate: Bool

    private static let colors = [
        FBPalette.lime,
        FBPalette.cyan,
        FBPalette.magenta,
        Color.white,
        FBPalette.violet,
    ]

    private var particleColor: Color {
        Self.colors[index % Self.colors.count]
    }

    private var particleSize: CGSize {
        CGSize(
            width: index.isMultiple(of: 3) ? 5 : 8,
            height: index.isMultiple(of: 4) ? 14 : 8
        )
    }

    private var particleOffset: CGSize {
        guard animate else { return .zero }

        let horizontalRadius = CGFloat(95 + (index % 6) * 18)
        let verticalRadius = CGFloat(95 + (index % 5) * 24)
        let horizontalWave = CGFloat(cos(Double(index) * 1.77))
        let verticalWave = CGFloat(sin(Double(index) * 2.13))

        return CGSize(
            width: horizontalWave * horizontalRadius,
            height: verticalWave * verticalRadius + 28
        )
    }

    private var particleAnimation: Animation {
        let duration = 1.1 + Double(index % 7) * 0.07
        let delay = Double(index % 5) * 0.025
        return .easeOut(duration: duration).delay(delay)
    }

    var body: some View {
        Capsule()
            .fill(particleColor)
            .frame(width: particleSize.width, height: particleSize.height)
            .rotationEffect(.degrees(animate ? Double(index * 83) : 0))
            .offset(particleOffset)
            .opacity(animate ? 0 : 1)
            .animation(particleAnimation, value: animate)
    }
}
