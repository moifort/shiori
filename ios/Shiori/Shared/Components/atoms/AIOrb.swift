import SwiftUI

/// The AI's avatar while it works: a small sphere in which the `AIGlow`
/// colours swirl under a gloss, as Siri's orb does. Two fields turn against
/// each other at different speeds so the colours cross rather than wheel
/// round; a soft light breathes at the centre. Still under Reduce Motion.
struct AIOrb: View {
    var size: CGFloat = 20

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            let turn = Angle.degrees(time.truncatingRemainder(dividingBy: 2.2) / 2.2 * 360)
            let turnBack = Angle.degrees(-time.truncatingRemainder(dividingBy: 3.1) / 3.1 * 360)
            let breath = (sin(time / 1.8 * 2 * .pi) + 1) / 2

            ZStack {
                Color(red: 0.08, green: 0.04, blue: 0.14)
                AngularGradient(colors: AIGlow.colors + [AIGlow.colors[0]], center: .center, angle: turn)
                    .scaleEffect(1.6)
                    .blur(radius: size * 0.12)
                ZStack {
                    RadialGradient(
                        colors: [.cyan, .clear], center: UnitPoint(x: 0.3, y: 0.7),
                        startRadius: 0, endRadius: size * 0.4
                    )
                    RadialGradient(
                        colors: [.pink, .clear], center: UnitPoint(x: 0.72, y: 0.3),
                        startRadius: 0, endRadius: size * 0.38
                    )
                }
                .rotationEffect(turnBack)
                .blendMode(.screen)
                Circle()
                    .fill(.white.opacity(0.35 + 0.3 * breath))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .scaleEffect(0.85 + 0.25 * breath)
                    .blur(radius: size * 0.1)
            }
            .saturation(1.3)
            .clipShape(Circle())
            .overlay {
                // The gloss: a highlight top left, the rim a little darker.
                ZStack {
                    RadialGradient(
                        colors: [.white.opacity(0.7), .clear], center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 0, endRadius: size * 0.26
                    )
                    RadialGradient(
                        colors: [.clear, .black.opacity(0.35)], center: .center,
                        startRadius: size * 0.28, endRadius: size * 0.5
                    )
                }
                .clipShape(Circle())
            }
            .frame(width: size, height: size)
            .shadow(color: .purple.opacity(0.55), radius: size * 0.2)
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        AIOrb()
        AIOrb(size: 60)
    }
    .padding(40)
    .background(.black)
}
