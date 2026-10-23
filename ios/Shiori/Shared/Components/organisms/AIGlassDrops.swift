import SwiftUI

/// The AI at work, in Liquid Glass: a drop of glass that buds smaller drops,
/// which drift around it and melt back in, over a soft spectral glow the glass
/// bends — the colours Apple Intelligence wears, so the wait reads as the AI's
/// without saying more. A sparkle breathes in the middle drop.
///
/// The drops share one `GlassEffectContainer`, which fuses glass shapes as they
/// near each other: moved every frame, they bud and merge like liquid. Shown
/// wherever a reader waits on the model with nothing else to look at — a cover
/// being read, a shelf being searched.
///
/// Respects Reduce Motion by holding the drops apart, still. Purely
/// presentational.
struct AIGlassDrops: View {
    /// Side of the square the drops and their glow are drawn in.
    var size: CGFloat = 220

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the drops start from the same pose on appear.
    @State private var start = Date()

    /// The drops that bud from the middle one: their size, how fast they turn,
    /// and where they start.
    private static let buds: [(diameter: CGFloat, speed: Double, phase: Double)] = [
        (0.24, 0.42, 0.0),
        (0.18, -0.31, 2.1),
        (0.21, 0.27, 4.2),
    ]

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 1.6 : context.date.timeIntervalSince(start)
            ZStack {
                glow(at: time)
                GlassEffectContainer(spacing: size * 0.12) {
                    ZStack {
                        drop(diameter: size * 0.40)
                            .overlay { sparkle }
                        ForEach(Self.buds.indices, id: \.self) { index in
                            let bud = Self.buds[index]
                            drop(diameter: size * bud.diameter)
                                .offset(offset(of: bud, at: time))
                        }
                    }
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    /// One drop of clear glass, faintly lit so it reads on a plain page.
    private func drop(diameter: CGFloat) -> some View {
        Circle()
            .fill(.white.opacity(0.01))
            .frame(width: diameter, height: diameter)
            .glassEffect(.clear.tint(.white.opacity(0.06)), in: .circle)
    }

    /// Where a bud sits: turning around the middle drop, drifting out until it
    /// stands apart, then sinking back in and fusing with it.
    private func offset(of bud: (diameter: CGFloat, speed: Double, phase: Double), at time: Double)
        -> CGSize
    {
        let angle = bud.phase + time * bud.speed * 2 * .pi / 3
        let breath = 0.5 + 0.5 * sin(time * 0.9 + bud.phase * 1.3)
        let distance = size * (0.12 + 0.24 * breath)
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }

    /// The spectral light behind the glass, turning slowly.
    private func glow(at time: Double) -> some View {
        Circle()
            .fill(
                AngularGradient(
                    colors: [.pink, .orange, .yellow, .mint, .cyan, .blue, .purple, .pink],
                    center: .center,
                    angle: .degrees(time * 40)
                )
            )
            .frame(width: size * 0.62, height: size * 0.62)
            .blur(radius: size * 0.12)
            .opacity(0.75)
            .scaleEffect(0.92 + 0.08 * sin(time * 1.1))
    }

    private var sparkle: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size * 0.12, weight: .medium))
            .foregroundStyle(.white)
            .shadow(color: .white.opacity(0.6), radius: 6)
            .symbolEffect(.breathe, isActive: !reduceMotion)
    }
}

#Preview("Light") {
    AIGlassDrops()
}

#Preview("Dark") {
    AIGlassDrops().preferredColorScheme(.dark)
}
