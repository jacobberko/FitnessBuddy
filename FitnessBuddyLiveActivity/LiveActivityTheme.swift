import SwiftUI

enum LiveActivityPalette {
    static let black = Color(red: 0.018, green: 0.020, blue: 0.024)
    static let elevatedBlack = Color(red: 0.045, green: 0.050, blue: 0.060)
    static let lime = Color(red: 0.78, green: 1.00, blue: 0.10)
    static let cyan = Color(red: 0.10, green: 0.93, blue: 0.90)
    static let violet = Color(red: 0.56, green: 0.35, blue: 1.00)
    static let magenta = Color(red: 1.00, green: 0.26, blue: 0.72)
    static let warm = Color(red: 1.00, green: 0.70, blue: 0.20)

    static let iridescent = LinearGradient(
        stops: [
            .init(color: lime, location: 0),
            .init(color: cyan, location: 0.30),
            .init(color: violet, location: 0.60),
            .init(color: magenta, location: 0.82),
            .init(color: lime, location: 1)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

struct LiveActivityBackdrop: View {
    var body: some View {
        ZStack {
            LiveActivityPalette.black

            RadialGradient(
                colors: [LiveActivityPalette.lime.opacity(0.19), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 190
            )

            RadialGradient(
                colors: [LiveActivityPalette.violet.opacity(0.22), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 220
            )

            LinearGradient(
                colors: [
                    LiveActivityPalette.cyan.opacity(0.06),
                    .clear,
                    LiveActivityPalette.magenta.opacity(0.08)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )

            MicroGrid()
                .opacity(0.33)
        }
        .ignoresSafeArea()
    }
}

private struct MicroGrid: View {
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var path = Path()

            for x in stride(from: CGFloat.zero, through: size.width, by: spacing) {
                for y in stride(from: CGFloat.zero, through: size.height, by: spacing) {
                    path.addEllipse(in: CGRect(x: x, y: y, width: 1, height: 1))
                }
            }

            context.fill(path, with: .color(.white.opacity(0.12)))
        }
        .allowsHitTesting(false)
    }
}

struct FitnessBuddyMark: View {
    var size: CGFloat = 22

    var body: some View {
        ZStack {
            ForEach([0.0, 45.0, 90.0, 135.0], id: \.self) { angle in
                Capsule(style: .continuous)
                    .fill(LiveActivityPalette.iridescent)
                    .frame(width: size, height: max(size * 0.22, 2.5))
                    .rotationEffect(.degrees(angle))
            }

            Circle()
                .fill(.white)
                .frame(width: size * 0.16, height: size * 0.16)
                .shadow(color: LiveActivityPalette.lime.opacity(0.9), radius: 3)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct WorkoutProgressBar: View {
    let progress: Double
    var height: CGFloat = 5

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(.white.opacity(0.10))

                Capsule(style: .continuous)
                    .fill(LiveActivityPalette.iridescent)
                    .frame(width: max(proxy.size.width * clampedProgress, clampedProgress > 0 ? height : 0))
                    .shadow(color: LiveActivityPalette.lime.opacity(0.38), radius: 6)
            }
        }
        .frame(height: height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Workout progress")
        .accessibilityValue("\(Int((clampedProgress * 100).rounded())) percent")
    }
}

struct WorkoutProgressRing: View {
    let progress: Double
    var size: CGFloat = 34
    var lineWidth: CGFloat = 3

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(clampedProgress, 0.018))
                .stroke(
                    LiveActivityPalette.iridescent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            FitnessBuddyMark(size: size * 0.42)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct RestCountdownText: View {
    let endDate: Date
    var showsHours = false

    var body: some View {
        let now = Date.now

        if endDate > now {
            Text(
                timerInterval: now...endDate,
                countsDown: true,
                showsHours: showsHours
            )
            .monospacedDigit()
            .contentTransition(.numericText(countsDown: true))
        } else {
            Text("READY")
        }
    }
}

extension View {
    /// Uses native Liquid Glass on iOS 26 while retaining a material-backed treatment on iOS 18.
    @ViewBuilder
    func liveActivityGlass(cornerRadius: CGFloat, tint: Color = .white) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(iOS 26.0, *) {
            self
                .background(shape.fill(.white.opacity(0.035)))
                .glassEffect(.regular.tint(tint.opacity(0.14)), in: shape)
                .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 0.75))
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background(
                    shape.fill(
                        LinearGradient(
                            colors: [tint.opacity(0.13), .white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .overlay(shape.stroke(.white.opacity(0.16), lineWidth: 0.75))
        }
    }
}
