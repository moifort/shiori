import SwiftUI

/// The AI at work, as an orb: the glow's colours breathing inside a sphere,
/// two soft blobs drifting through it and a crescent of light turning around
/// its rim, the way Siri's orb moves while it listens. Shown wherever a reader
/// waits on the model with nothing else to look at — a cover being read, a
/// shelf being searched. The same colours sweep the bar's "L'IA complète…"
/// label, so the two read as one AI.
///
/// Built from the layering of open-source Siri-style orbs: a gradient base,
/// blurred rotating shapes with `.plusLighter`, inner rim strokes, everything
/// masked to a circle. Here the base is a `MeshGradient` whose inner points
/// breathe on the glow's clock, which is cheaper than stacking rotating
/// gradients and gives the colours a slow churn of their own.
///
/// Respects Reduce Motion by holding one frame. Purely presentational.
struct AIOrb: View {
    /// Diameter in points.
    var size: CGFloat = 160

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the orb starts from the same pose on appear.
    @State private var start = Date()

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            ZStack {
                base(at: t)
                blob(at: t, seed: 0, scale: 0.62)
                blob(at: t, seed: 1, scale: 0.52)
                crescent(at: t)
                rim
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .shadow(color: AIGlow.colors[1].opacity(0.3), radius: size * 0.12, y: size * 0.04)
            .shadow(color: AIGlow.colors[0].opacity(0.2), radius: size * 0.25)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Layers

    /// The glow's four colours on a 3×3 mesh, the centre and the mid-edge
    /// points breathing on the glow's clock so the colours slowly churn.
    private func base(at t: TimeInterval) -> some View {
        let w = 2 * .pi / AIGlow.period
        let drift: (Double, Double) -> Float = { phase, amount in
            Float(sin(t * w * 0.5 + phase) * amount)
        }
        return MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5 + drift(0, 0.12), 0], [1, 0],
                [0, 0.5 + drift(1.3, 0.12)], [0.5 + drift(2.1, 0.18), 0.5 + drift(0.7, 0.18)], [1, 0.5 + drift(2.9, 0.12)],
                [0, 1], [0.5 + drift(1.8, 0.12), 1], [1, 1],
            ],
            colors: [
                AIGlow.colors[0], AIGlow.colors[1], AIGlow.colors[2],
                AIGlow.colors[3], AIGlow.colors[0], AIGlow.colors[1],
                AIGlow.colors[2], AIGlow.colors[3], AIGlow.colors[0],
            ]
        )
    }

    /// A soft blob drifting on a slow Lissajous path, blurred into light, its
    /// colour turning through the glow's four as it goes. Two of them, out of
    /// phase, give the orb its inner life and keep every colour in play.
    private func blob(at t: TimeInterval, seed: Double, scale: CGFloat) -> some View {
        let w = 2 * .pi / AIGlow.period
        let x = sin(t * w * 0.37 + seed * 2.3) * size * 0.22
        let y = cos(t * w * 0.29 + seed * 1.7) * size * 0.22
        // One colour per glow cycle, cross-faded through an angular gradient
        // spun by the clock: the blob never snaps from one to the next.
        let turn = Angle.radians(t * w * 0.5 + seed * .pi)
        return Circle()
            .fill(AngularGradient(colors: AIGlow.colors + [AIGlow.colors[0]], center: .center, angle: turn))
            .frame(width: size * scale, height: size * scale)
            .blur(radius: size * 0.14)
            .offset(x: x, y: y)
            .opacity(0.85)
            .blendMode(.plusLighter)
    }

    /// A crescent of white light turning around the rim: a circle minus an
    /// offset circle, blurred, rotated on the glow's clock.
    private func crescent(at t: TimeInterval) -> some View {
        let w = 2 * .pi / AIGlow.period
        return Circle()
            .fill(.white)
            .mask {
                ZStack {
                    Circle()
                    Circle()
                        .scale(1.18)
                        .offset(y: size * 0.26)
                        .blendMode(.destinationOut)
                }
            }
            .blur(radius: size * 0.09)
            .opacity(0.55)
            .rotationEffect(.radians(t * w * 0.25))
            .blendMode(.plusLighter)
    }

    /// Thin strokes just inside the edge, brighter at the bottom, that turn a
    /// disc of colour into a sphere.
    private var rim: some View {
        let edge = LinearGradient(colors: [.white, .clear], startPoint: .bottom, endPoint: .top)
        return ZStack {
            Circle().stroke(edge, lineWidth: size * 0.05).blur(radius: size * 0.2)
            Circle().stroke(edge, lineWidth: size * 0.025).blur(radius: size * 0.075)
            Circle().stroke(edge, lineWidth: 1).blur(radius: size * 0.025)
        }
        .padding(1)
        .blendMode(.plusLighter)
    }
}

#Preview("Light") {
    AIOrb()
}

#Preview("Dark") {
    AIOrb().preferredColorScheme(.dark)
}
