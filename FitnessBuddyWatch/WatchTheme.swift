import SwiftUI

enum WatchPalette {
    static let ink = Color.black
    static let lime = Color(red: 0.72, green: 1.0, blue: 0.08)
    static let cyan = Color(red: 0.08, green: 0.94, blue: 0.92)
    static let violet = Color(red: 0.62, green: 0.30, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.20, blue: 0.72)
    static let muted = Color.white.opacity(0.58)

    static let iridescent = AngularGradient(
        colors: [lime, cyan, violet, magenta, lime],
        center: .center
    )
}

struct WatchIridescentBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: reduceMotion)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 14) / 14

            ZStack {
                WatchPalette.ink

                Circle()
                    .fill(WatchPalette.iridescent)
                    .frame(width: 160, height: 160)
                    .blur(radius: 44)
                    .opacity(0.20)
                    .offset(x: -54, y: -104)
                    .rotationEffect(.degrees(phase * 360))

                Circle()
                    .fill(WatchPalette.iridescent)
                    .frame(width: 120, height: 120)
                    .blur(radius: 38)
                    .opacity(0.13)
                    .offset(x: 70, y: 124)
                    .rotationEffect(.degrees(-phase * 360))

                LinearGradient(
                    colors: [.clear, WatchPalette.lime.opacity(0.055), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
    }
}

struct WatchGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        if #available(watchOS 26.0, *) {
            content
                .background(Color.white.opacity(0.035), in: shape)
                .glassEffect(
                    .regular.tint(Color.white.opacity(0.045)),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay { glassBorder(shape) }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.075), WatchPalette.violet.opacity(0.055)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: shape
                )
                .overlay { glassBorder(shape) }
        }
    }

    private func glassBorder(_ shape: RoundedRectangle) -> some View {
        shape
            .stroke(
                LinearGradient(
                    colors: [WatchPalette.lime.opacity(0.46), .white.opacity(0.16), WatchPalette.violet.opacity(0.28)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.7
            )
            .allowsHitTesting(false)
    }
}

extension View {
    func watchGlassCard(cornerRadius: CGFloat = 18) -> some View {
        modifier(WatchGlassCardModifier(cornerRadius: cornerRadius))
    }
}

struct WatchNeonButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .black, design: .rounded))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(WatchPalette.lime, in: Capsule())
            .shadow(color: WatchPalette.lime.opacity(configuration.isPressed ? 0.18 : 0.48), radius: configuration.isPressed ? 3 : 10)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.68), value: configuration.isPressed)
    }
}

struct WatchSectionLabel: View {
    let index: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Text(index)
                .foregroundStyle(WatchPalette.lime)
            Text(title.uppercased())
                .foregroundStyle(WatchPalette.muted)
            Spacer(minLength: 0)
        }
        .font(.system(size: 9, weight: .bold, design: .monospaced))
        .tracking(0.7)
    }
}
