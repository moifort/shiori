import SwiftUI

/// The brand mark drawn on screen: `ShioriMark`'s ribbon, hanging bare on
/// whatever is behind it, with the motion the moment calls for.
///
/// - `.loop` is the app opening, spent on the launch gate alone: the ribbon
///   drops in from above the frame, settles with a little overshoot, swings
///   twice and comes to rest, then lifts away and starts over.
/// - `.once` is the entrance for the sign-in and welcome screens: the drop and
///   the swing, after which the ribbon hangs still and the view stops drawing.
/// - `.still` is the mark at rest.
///
/// Respects Reduce Motion by holding the resting pose whatever the motion.
struct RibbonMark: View {
    enum Motion {
        case still
        case once
        case loop
    }

    var motion: Motion = .still
    /// Height in points; the width follows the design proportions, with room
    /// on each side for the swing.
    var height: CGFloat = 120

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time, so the ribbon starts above the frame on appear.
    @State private var start = Date()
    @State private var entranceOver = false

    /// Seconds for one full cycle: drop, swing, rest, lift.
    private static let period: TimeInterval = 3.2
    /// The fraction of the cycle after which a `.once` mark is at rest.
    private static let entranceEnd = 0.72
    /// Radians at the first swing; each pass loses some.
    private static let swingAmplitude = 0.06

    /// The view's design box on the mark's canvas: the ribbon plus headroom
    /// on each side for the swing.
    private static let designWidth: CGFloat = ShioriMark.ribbonWidth + 2 * 70
    private static let designHeight: CGFloat = ShioriMark.ribbonLength

    var body: some View {
        TimelineView(.animation(paused: paused)) { context in
            let pose = reduceMotion || motion == .still
                ? Pose.resting
                : Self.pose(
                    at: context.date.timeIntervalSince(start),
                    looping: motion == .loop
                )
            Canvas { ctx, size in
                Self.draw(&ctx, canvasSize: size, pose: pose)
            }
        }
        .frame(width: height * Self.designWidth / Self.designHeight, height: height)
        .task(id: motion) {
            guard motion == .once else { return }
            try? await Task.sleep(for: .seconds(Self.period * Self.entranceEnd))
            entranceOver = true
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Shiori"))
    }

    private var paused: Bool {
        reduceMotion || motion == .still || (motion == .once && entranceOver)
    }

    // MARK: - Motion

    /// Everything the drawing needs to know about one instant.
    struct Pose {
        /// Where the ribbon is: 0 above the frame, 1 hanging in place.
        var drop: Double
        /// The swing about the pivot, in radians, positive clockwise.
        var swing: Double

        static let resting = Pose(drop: 1, swing: 0)
    }

    /// The pose at `time`. A `.once` mark plays the cycle up to the rest and
    /// stays there; a looping one goes on to lift away and start over.
    static func pose(at time: TimeInterval, looping: Bool) -> Pose {
        let elapsed = looping ? time.truncatingRemainder(dividingBy: period) : time
        let cycle = elapsed / period
        switch cycle {
        case ..<0.20:
            return Pose(drop: settle(cycle / 0.20), swing: 0)
        case ..<entranceEnd:
            let u = (cycle - 0.20) / (entranceEnd - 0.20)
            let swing = swingAmplitude * sin(2 * .pi * 2 * u) * (1 - u)
            return Pose(drop: 1, swing: swing)
        case ..<0.86:
            return .resting
        default:
            return Pose(drop: 1 - easeIn((cycle - 0.86) / 0.14), swing: 0)
        }
    }

    private static func easeIn(_ x: Double) -> Double {
        x * x * x
    }

    /// Ease out with a small overshoot, so the ribbon lands and settles rather
    /// than stopping dead.
    private static func settle(_ x: Double) -> Double {
        let c1 = 0.7
        let c3 = c1 + 1
        return 1 + c3 * pow(x - 1, 3) + c1 * pow(x - 1, 2)
    }

    // MARK: - Drawing

    /// Draws one frame. Internal so previews can lay out fixed poses side by side.
    static func draw(_ ctx: inout GraphicsContext, canvasSize: CGSize, pose: Pose) {
        let scale = min(canvasSize.width / designWidth, canvasSize.height / designHeight)
        ctx.translateBy(
            x: (canvasSize.width - designWidth * scale) / 2,
            y: (canvasSize.height - designHeight * scale) / 2
        )
        ctx.scaleBy(x: scale, y: scale)
        // The design box is the middle of the mark's canvas.
        ctx.translateBy(x: designWidth / 2 - ShioriMark.pivot.x, y: 0)

        // Above the frame by however much of the fall is left, then swung
        // about the point where the ribbon is held.
        ctx.translateBy(x: 0, y: -(1 - pose.drop) * (designHeight + 20))
        ctx.translateBy(x: ShioriMark.pivot.x, y: ShioriMark.pivot.y)
        ctx.rotate(by: .radians(pose.swing))
        ctx.translateBy(x: -ShioriMark.pivot.x, y: -ShioriMark.pivot.y)

        ctx.fill(Path(ShioriMark.ribbon()), with: .color(.bookmarkRibbon))
        ctx.fill(Path(ShioriMark.fold()), with: .color(Color(ShioriMark.foldColor)))
    }
}

extension Color {
    /// The one saturated colour of the brand: the bookmark ribbon.
    static let bookmarkRibbon = Color(ShioriMark.ribbonColor)

    init(_ rgb: ShioriMark.RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

#Preview("Loop") {
    RibbonMark(motion: .loop, height: 150)
}

#Preview("Once") {
    RibbonMark(motion: .once)
}

#Preview("Poses") {
    let poses: [RibbonMark.Pose] = [
        .init(drop: 0.3, swing: 0),
        .init(drop: 1.05, swing: 0),
        .init(drop: 1, swing: 0.06),
        .init(drop: 1, swing: -0.04),
        .resting,
    ]
    HStack(spacing: 16) {
        ForEach(Array(poses.enumerated()), id: \.offset) { _, pose in
            Canvas { ctx, size in
                RibbonMark.draw(&ctx, canvasSize: size, pose: pose)
            }
            .frame(width: 50, height: 150)
        }
    }
    .padding()
}
