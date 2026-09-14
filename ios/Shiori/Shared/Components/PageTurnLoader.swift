import SwiftUI

/// An open book with a page turning, drawn and animated in a `Canvas`. The two
/// halves rest at a slight angle, and a single leaf sweeps from the right stack
/// to the left one, narrowing as it passes the spine so it reads as a page
/// caught mid-turn rather than a rectangle sliding across.
///
/// The branded replacement for a bare spinner on long cold-start loads. Respects
/// Reduce Motion by holding one static frame, page at rest on the right. Purely
/// presentational.
struct PageTurnLoader: View {
    /// Layout width in points; the height follows the book proportions.
    var size: CGFloat = 110

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the turn starts from the same pose on appear.
    @State private var start = Date()

    /// Seconds for one full page turn, including the pause at rest.
    private let period: TimeInterval = 1.6

    // Design space: the book is drawn in a fixed 100 x 72 coordinate box, then
    // scaled to fit the canvas. The stroke weight matches the SF Symbol `book`
    // so the loader reads as the same icon, caught in motion.
    private static let designWidth: CGFloat = 100
    private static let designHeight: CGFloat = 72
    private static let spineX: CGFloat = 50
    private static let spineTopY: CGFloat = 14
    private static let spineBottomY: CGFloat = 62
    private static let edgeX: CGFloat = 8
    private static let edgeTopY: CGFloat = 20
    private static let strokeWidth: CGFloat = 2

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let time = reduceMotion ? 0 : context.date.timeIntervalSince(start)
            Canvas { ctx, canvasSize in
                draw(&ctx, canvasSize: canvasSize, time: time)
            }
        }
        .frame(width: size, height: size * Self.designHeight / Self.designWidth)
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: inout GraphicsContext, canvasSize: CGSize, time: TimeInterval) {
        let scale = min(canvasSize.width / Self.designWidth, canvasSize.height / Self.designHeight)
        ctx.translateBy(
            x: (canvasSize.width - Self.designWidth * scale) / 2,
            y: (canvasSize.height - Self.designHeight * scale) / 2
        )
        ctx.scaleBy(x: scale, y: scale)

        let stroke = StrokeStyle(lineWidth: Self.strokeWidth, lineCap: .round, lineJoin: .round)
        let ink = GraphicsContext.Shading.color(.primary)
        let faded = GraphicsContext.Shading.color(.secondary.opacity(0.55))

        // Both resting stacks, mirrored around the spine.
        ctx.stroke(halfPage(mirrored: false), with: ink, style: stroke)
        ctx.stroke(halfPage(mirrored: true), with: ink, style: stroke)

        // The spine itself, which the turning leaf pivots on.
        var spine = Path()
        spine.move(to: CGPoint(x: Self.spineX, y: Self.spineTopY))
        spine.addLine(to: CGPoint(x: Self.spineX, y: Self.spineBottomY))
        ctx.stroke(spine, with: ink, style: stroke)

        // `progress` runs 0 → 1 over the turn, then holds at rest for the
        // remainder of the period so the eye gets a beat between pages.
        let cycle = time.truncatingRemainder(dividingBy: period) / period
        let progress = min(cycle / 0.72, 1)
        let eased = progress * progress * (3 - 2 * progress)
        ctx.stroke(turningLeaf(progress: eased), with: faded, style: stroke)
    }

    /// One resting half of the book: the outer edge, curving up to the spine.
    private func halfPage(mirrored: Bool) -> Path {
        let outerX = mirrored ? Self.designWidth - Self.edgeX : Self.edgeX
        var path = Path()
        path.move(to: CGPoint(x: Self.spineX, y: Self.spineTopY))
        path.addQuadCurve(
            to: CGPoint(x: outerX, y: Self.edgeTopY),
            control: CGPoint(x: (Self.spineX + outerX) / 2, y: Self.spineTopY - 4)
        )
        path.addLine(to: CGPoint(x: outerX, y: Self.spineBottomY - 6))
        path.addQuadCurve(
            to: CGPoint(x: Self.spineX, y: Self.spineBottomY),
            control: CGPoint(x: (Self.spineX + outerX) / 2, y: Self.spineBottomY - 2)
        )
        return path
    }

    /// The leaf in flight. Its free edge travels from the right stack to the
    /// left one; the horizontal squeeze at the halfway point is what sells the
    /// page as standing upright rather than lying flat.
    private func turningLeaf(progress: Double) -> Path {
        let rightX = Self.designWidth - Self.edgeX
        let leftX = Self.edgeX
        let freeX = rightX + (leftX - rightX) * progress
        // Widest gap from the spine at the extremes, none as it passes upright.
        let squeeze = abs(freeX - Self.spineX) / (rightX - Self.spineX)
        let lift = (1 - squeeze) * 10

        var path = Path()
        path.move(to: CGPoint(x: Self.spineX, y: Self.spineTopY))
        path.addQuadCurve(
            to: CGPoint(x: freeX, y: Self.edgeTopY - lift),
            control: CGPoint(x: (Self.spineX + freeX) / 2, y: Self.spineTopY - 6 - lift)
        )
        path.addLine(to: CGPoint(x: freeX, y: Self.spineBottomY - 6 - lift))
        path.addQuadCurve(
            to: CGPoint(x: Self.spineX, y: Self.spineBottomY),
            control: CGPoint(x: (Self.spineX + freeX) / 2, y: Self.spineBottomY - 2 - lift)
        )
        return path
    }
}

#Preview {
    PageTurnLoader()
}
