import SwiftUI

/// The brand mark drawn on screen: the app icon itself, `ShioriMark`'s
/// ribbon hanging in its cream rounded square, with the motion the moment
/// calls for. Drawn at icon proportions so it reads as the icon at any size;
/// bare, the ribbon is too thin to be anything but a red stroke.
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
    /// Side of the square, in points.
    var size: CGFloat = 120

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

    /// The corner of an iOS icon, as a fraction of its side.
    private static let cornerRatio: CGFloat = 0.2237
    /// How far the ribbon runs on above the field, in canvas units. The icon's
    /// ribbon ends exactly on the top edge, which holds only while it hangs
    /// still: the landing overshoot pulls it down (about 16 units) and the
    /// swing dips a top corner under the edge, and either would show its cut
    /// end as a sliver of cream. Carried on past the clip, it always reads as
    /// coming out from behind the page.
    private static let overhang: CGFloat = 80

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
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.14), radius: size * 0.06, y: size * 0.03)
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
        let side = ShioriMark.canvas
        let scale = min(canvasSize.width, canvasSize.height) / side
        ctx.translateBy(
            x: (canvasSize.width - side * scale) / 2,
            y: (canvasSize.height - side * scale) / 2
        )
        ctx.scaleBy(x: scale, y: scale)

        let field = Path(
            roundedRect: CGRect(x: 0, y: 0, width: side, height: side),
            cornerRadius: side * cornerRatio,
            style: .continuous
        )
        ctx.fill(field, with: .color(Color(ShioriMark.fieldColor)))
        // The ribbon slides in over the top edge of the field, so it is
        // clipped to it rather than appearing out of nowhere above.
        ctx.clip(to: field)

        // Above the field by however much of the fall is left, then swung
        // about the point where the ribbon is held.
        ctx.translateBy(x: 0, y: -(1 - pose.drop) * (ShioriMark.ribbonLength + 20))
        ctx.translateBy(x: ShioriMark.pivot.x, y: ShioriMark.pivot.y)
        ctx.rotate(by: .radians(pose.swing))
        ctx.translateBy(x: -ShioriMark.pivot.x, y: -ShioriMark.pivot.y)

        ctx.fill(Path(ShioriMark.ribbon()), with: .color(.bookmarkRibbon))
        // The fold band, carried on above the edge by the overhang.
        let fold = ShioriMark.fold().boundingBox
        ctx.fill(
            Path(CGRect(
                x: fold.minX, y: fold.minY - overhang,
                width: fold.width, height: fold.height + overhang
            )),
            with: .color(Color(ShioriMark.foldColor))
        )
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
    RibbonMark(motion: .loop, size: 140)
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
            .frame(width: 100, height: 100)
        }
    }
    .padding()
}
