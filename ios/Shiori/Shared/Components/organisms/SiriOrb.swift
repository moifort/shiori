import SwiftUI

/// The AI at work, as Siri's orb: red, blue and green lobes of light turn and
/// tip, edge-on lobes reading as ribbons, and the crossings burn to white.
/// Shown where a reader waits on the model with nothing else to look at, such
/// as a shelf being searched.
///
/// Built from Vinarium's `SiriLoader`, itself a port of Amos Gyamfi's
/// ListeningSiriAnimation (GetStream/purposeful-ios-animations): its vector
/// layers in `Assets.xcassets/Siri/`, with their rotations and 3D tilts. Moved
/// toward Apple's orb: each pale layer is tinted to a pure Siri colour and
/// added as light (`.plusLighter`) rather than `.hardLight`, straight on black
/// with no sphere behind, centred and clipped round. The phase eases back and
/// forth between two poses, so the loop has no seam.
///
/// Drawn over black, so it belongs on a dark page. Respects Reduce Motion by
/// holding one frame. Purely presentational.
struct SiriOrb: View {
    /// Layout footprint; the artwork (largest layer ≈ 640 pt) is scaled to fit.
    var size: CGFloat = 300

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the loop starts at its midpoint on appear.
    @State private var start = Date()

    /// Seconds for one pose-A → pose-B traversal; the full loop takes twice this.
    private let period: TimeInterval = 12
    private var scale: CGFloat { size / 520 }

    private static let red = Color(red: 1, green: 0.16, blue: 0.33)
    private static let blue = Color(red: 0.18, green: 0.42, blue: 1)
    private static let cyan = Color(red: 0.37, green: 0.95, blue: 1)
    private static let green = Color(red: 0.18, green: 0.88, blue: 0.62)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let t = reduceMotion ? 0.5 : phase(at: context.date)
            orb(phase: t)
                .scaleEffect(scale)
                .frame(width: size, height: size)
                .background(Color.black)
                .clipShape(Circle().scale(0.9))
                .compositingGroup()
                .mask { fadeToRound }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Softens the sphere's edge into the page.
    private var fadeToRound: some View {
        RadialGradient(
            stops: [
                .init(color: .black, location: 0),
                .init(color: .black, location: 0.8),
                .init(color: .clear, location: 1),
            ],
            center: .center,
            startRadius: 0,
            endRadius: size / 2
        )
    }

    /// Cycle position in `0...1`, easing 0 → 1 → 0 with no seam; starts at 0.5.
    private func phase(at date: Date) -> Double {
        let cycle = date.timeIntervalSince(start) / (period * 2) + 0.25
        return (1 - cos(2 * .pi * cycle)) / 2
    }

    private func mix(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }

    /// One pale layer tinted to a Siri colour, turned and tipped in 3D, added
    /// as light so the crossings burn to white.
    private func layer(
        _ name: String,
        _ color: Color,
        spin: (Double, Double),
        tilt: Double,
        axis: (CGFloat, CGFloat, CGFloat),
        hue: Double,
        _ t: Double,
        alpha: Double = 0.8,
        grow: CGFloat = 1
    ) -> some View {
        Image("Siri/\(name)")
            .colorMultiply(color)
            .saturation(1.6)
            .opacity(alpha)
            .scaleEffect(grow)
            .rotationEffect(.degrees(mix(spin.0, spin.1, t)))
            .hueRotation(.degrees(hue * sin(t * .pi * 2)))
            .rotation3DEffect(.degrees(tilt), axis: axis)
            .blendMode(.plusLighter)
    }

    private func orb(phase t: Double) -> some View {
        ZStack {
            layer("pink-left", Self.red, spin: (-360, 180), tilt: 0, axis: (0, 0, 1), hue: 8, t, alpha: 0.9, grow: 1.35)
            layer("pink-top", Self.red, spin: (320, -360), tilt: 0, axis: (0, 0, 1), hue: 8, t, alpha: 0.9, grow: 1.4)
            layer("blue-right", Self.blue, spin: (-360, 420), tilt: 70, axis: (1, 0, CGFloat(mix(-5, 15, t))), hue: 10, t)
            layer("blue-middle", Self.blue, spin: (-360, 420), tilt: 72, axis: (CGFloat(mix(1, 5, t)), 0, 0), hue: 10, t)
            layer("green-right", Self.green, spin: (-180, 480), tilt: 30, axis: (1, CGFloat(mix(-1, 1, t)), 0), hue: 10, t, alpha: 0.6)
            layer("green-left", Self.green, spin: (240, -480), tilt: 74, axis: (1, CGFloat(mix(-5, 15, t)), 0), hue: 10, t)
            layer("intersect", Self.cyan, spin: (30, -420), tilt: 70, axis: (1, 1, 1), hue: 12, t, alpha: 0.42)
            layer("bottom-pink", Self.red, spin: (400, -360), tilt: 74, axis: (5, CGFloat(mix(1, -45, t)), 0), hue: 8, t)
            Image("Siri/highlight")
                .opacity(0.3)
                .blendMode(.plusLighter)
                .rotationEffect(.degrees(mix(360, 250, t)))
                .scaleEffect(0.6)
        }
        .frame(width: 640, height: 640)
    }
}

#Preview {
    SiriOrb()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        .preferredColorScheme(.dark)
}
