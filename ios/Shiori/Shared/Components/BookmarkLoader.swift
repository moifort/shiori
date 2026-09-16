import SwiftUI

/// A heavy grimoire being marked and closed, drawn and animated in a `Canvas`
/// in a few flat colours. The tome lies open on a table, seen from above, in
/// front and a little to the right: two thick blocks of cream pages on dark
/// leather boards, their edges showing along the near side and the right. The
/// brand's red ribbon drops from above into the gutter and settles, tail
/// hanging over the front. The right board then swings over on the spine,
/// block and all, and the book closes into a fat tome with tooled cover,
/// metal corners and a banded spine on its right. It rests, opens again, and
/// the ribbon lifts away so the cycle can start over. Shiori (栞) means
/// bookmark, so the wait is the app's own gesture rather than a spinner.
///
/// Every face is placed in three dimensions (across, back, up) and projected
/// so that height shows as an offset up and slightly left, which is what lets
/// the right half turn as one solid piece, stack correctly on the left, and
/// show its spine once it is over.
///
/// The branded replacement for a bare spinner on long cold-start loads.
/// Respects Reduce Motion by holding one static frame, the book open with
/// the ribbon in place. Purely presentational.
struct BookmarkLoader: View {
    /// Layout width in points; the height follows the design proportions.
    var size: CGFloat = 132

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Anchor for elapsed time so the scene starts from the same pose on appear.
    @State private var start = Date()

    /// Seconds for one full cycle: drop, close, rest, open, lift.
    private let period: TimeInterval = 4.2

    // Design space: 130 wide, 140 tall, with headroom for the right half
    // standing upright. `x` runs across, `z` from the back of the table
    // (small) to the front (large), `h` up from it. A point lands on screen at
    // (x - lean * h, z - h): the lean is what exposes the faces on the right.
    private static let designWidth: CGFloat = 130
    private static let designHeight: CGFloat = 140
    private static let lean: CGFloat = 0.12
    private static let spineX: CGFloat = 62
    private static let boardWidth: CGFloat = 56
    private static let boardBack: CGFloat = 66
    private static let boardFront: CGFloat = 130
    private static let boardThickness: CGFloat = 3
    /// The page block sits inside the board by this much on the three free sides.
    private static let blockInset: CGFloat = 3
    private static let blockThickness: CGFloat = 12
    private static let textRows: [CGFloat] = [81, 89, 97, 105]
    private static let ribbonWidth: CGFloat = 6.5
    private static let ribbonTail: CGFloat = 6
    private static let notchDepth: CGFloat = 3.5

    // Palette: leather, its shaded side and tooling, the pages, the metal.
    private static let leather = Color(red: 0.33, green: 0.22, blue: 0.17)
    private static let leatherShade = Color(red: 0.24, green: 0.15, blue: 0.12)
    private static let leatherLine = Color(red: 0.50, green: 0.36, blue: 0.28)
    private static let pages = Color(red: 0.96, green: 0.93, blue: 0.86)
    private static let pageEdge = Color(red: 0.88, green: 0.84, blue: 0.75)
    private static let pageLine = Color(red: 0.78, green: 0.73, blue: 0.64)
    private static let metal = Color(red: 0.80, green: 0.68, blue: 0.42)

    var body: some View {
        TimelineView(.animation(paused: reduceMotion)) { context in
            let pose = reduceMotion
                ? Pose(ribbonDrop: 1, closing: 0)
                : Self.pose(at: context.date.timeIntervalSince(start), period: period)
            Canvas { ctx, canvasSize in
                Self.draw(&ctx, canvasSize: canvasSize, pose: pose)
            }
        }
        .frame(width: size, height: size * Self.designHeight / Self.designWidth)
        .accessibilityHidden(true)
    }

    // MARK: - Motion

    /// Everything the drawing needs to know about one instant.
    struct Pose {
        /// Where the ribbon is: 0 above the frame, 1 settled in the gutter.
        var ribbonDrop: Double
        /// How far the right half has swung: 0 open flat, 1 closed on the left.
        var closing: Double
    }

    /// The pose at `time`. Each beat is followed by a short rest so the eye
    /// reads one gesture at a time: the ribbon lands, then the book closes,
    /// then it opens, then the ribbon leaves.
    static func pose(at time: TimeInterval, period: TimeInterval) -> Pose {
        let cycle = time.truncatingRemainder(dividingBy: period) / period
        switch cycle {
        case ..<0.08:
            return Pose(ribbonDrop: 0, closing: 0)
        case ..<0.24:
            return Pose(ribbonDrop: settle((cycle - 0.08) / 0.16), closing: 0)
        case ..<0.34:
            return Pose(ribbonDrop: 1, closing: 0)
        case ..<0.58:
            return Pose(ribbonDrop: 1, closing: easeInOut((cycle - 0.34) / 0.24))
        case ..<0.72:
            return Pose(ribbonDrop: 1, closing: 1)
        case ..<0.91:
            return Pose(ribbonDrop: 1, closing: 1 - easeInOut((cycle - 0.72) / 0.19))
        default:
            return Pose(ribbonDrop: 1 - easeIn((cycle - 0.91) / 0.09), closing: 0)
        }
    }

    private static func easeInOut(_ x: Double) -> Double {
        x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2
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

        let angle = pose.closing * .pi
        let left = Half(side: -1, angle: 0)
        let right = Half(side: 1, angle: angle)

        drawHalf(&ctx, left)

        // The right board's shadow falling across the left page as it comes
        // down: its footprint, cast straight down onto the page and kept
        // inside it, darkening as the board gets close.
        if cos(angle) < 0 {
            let shade = 0.05 + 0.17 * min(1, -cos(angle) * 1.5)
            ctx.drawLayer { layer in
                layer.clip(to: left.pageFace)
                layer.fill(right.boardShadow, with: .color(.black.opacity(shade)))
            }
        }

        // The part of the ribbon lying on the page goes under the spine and
        // the closing half, which is what tucks it into the book.
        ctx.fill(ribbonOnPage(drop: pose.ribbonDrop), with: .color(.bookmarkRibbon))

        // The spine, stretched between the two hinges. Flat and hidden while
        // the book is open, it stands up on the right as the book closes.
        if right.spineVisible {
            ctx.fill(right.spine, with: .color(leatherShade))
            ctx.stroke(right.spineBands, with: .color(leatherLine), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
        }

        drawHalf(&ctx, right)

        // The tail hangs down the front of the block, in front of everything.
        ctx.fill(ribbonTail(drop: pose.ribbonDrop), with: .color(.bookmarkRibbon))
    }

    /// One half of the book, boards and block. Faces are drawn back to front
    /// and bottom to top, skipping the ones turned away from the viewer.
    private static func drawHalf(_ ctx: inout GraphicsContext, _ half: Half) {
        if cos(half.angle) >= 0 {
            if half.visible(nx: 0, nh: -1) { ctx.fill(half.boardOutside, with: .color(leather)) }
            ctx.fill(half.boardFront, with: .color(leatherShade))
            if half.visible(nx: 0, nh: 1) { ctx.fill(half.boardTop, with: .color(leather)) }
            if half.visible(nx: 1, nh: 0) { ctx.fill(half.boardSide, with: .color(leatherShade)) }
            ctx.fill(half.blockFront, with: .color(pageEdge))
            ctx.stroke(half.blockFrontLines, with: .color(pageLine), lineWidth: 0.8)
            if half.visible(nx: 1, nh: 0) {
                ctx.fill(half.blockSide, with: .color(pageEdge))
                ctx.stroke(half.blockSideLines, with: .color(pageLine), lineWidth: 0.8)
            }
            if half.visible(nx: 0, nh: 1) {
                ctx.fill(half.pageFace, with: .color(pages))
                ctx.fill(half.pageFace, with: .linearGradient(
                    Gradient(colors: [.black.opacity(0.12), .clear]),
                    startPoint: half.point(dx: 0, z: 0, h: half.pageHeight),
                    endPoint: half.point(dx: 14, z: 0, h: half.pageHeight)
                ))
                ctx.stroke(half.textLines, with: .color(pageLine), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
        } else {
            ctx.fill(half.blockFront, with: .color(pageEdge))
            ctx.stroke(half.blockFrontLines, with: .color(pageLine), lineWidth: 0.8)
            if half.visible(nx: 1, nh: 0) {
                ctx.fill(half.blockSide, with: .color(pageEdge))
                ctx.stroke(half.blockSideLines, with: .color(pageLine), lineWidth: 0.8)
            }
            ctx.fill(half.boardFront, with: .color(leatherShade))
            if half.visible(nx: 1, nh: 0) { ctx.fill(half.boardSide, with: .color(leatherShade)) }
            if half.visible(nx: 0, nh: -1) {
                ctx.fill(half.boardOutside, with: .color(leather))
                ctx.stroke(half.tooling, with: .color(leatherLine), lineWidth: 1.4)
                ctx.fill(half.corners, with: .color(metal))
            }
        }
    }

    /// The ribbon is drawn in two pieces so it can sit at two depths: the
    /// length lying in the gutter on the left page, and the tail that hangs
    /// down the front of the block and trails on the table. Both are offset
    /// above their resting place by however much of the fall is left.

    private static func ribbonOnPage(drop: Double) -> Path {
        let left = Half(side: -1, angle: 0)
        let h = left.pageHeight
        let w = ribbonWidth
        var path = Path()
        path.move(to: left.point(dx: w, z: boardBack - 2, h: h))
        path.addLine(to: left.point(dx: 0, z: boardBack - 2, h: h))
        path.addLine(to: left.point(dx: 0, z: boardFront, h: h))
        path.addLine(to: left.point(dx: w, z: boardFront, h: h))
        path.closeSubpath()
        return path.applying(ribbonFall(drop: drop))
    }

    /// Straight down from where the page part ends, so the whole ribbon reads
    /// as one flat band rather than kinking where it leaves the page.
    private static func ribbonTail(drop: Double) -> Path {
        let left = Half(side: -1, angle: 0)
        let h = left.pageHeight
        let right = left.point(dx: 0, z: boardFront, h: h)
        let leftEdge = left.point(dx: ribbonWidth, z: boardFront, h: h)
        let end = boardFront + ribbonTail
        let middle = (right.x + leftEdge.x) / 2
        var path = Path()
        path.move(to: CGPoint(x: leftEdge.x, y: leftEdge.y))
        path.addLine(to: CGPoint(x: right.x, y: right.y))
        path.addLine(to: CGPoint(x: right.x, y: end))
        path.addLine(to: CGPoint(x: middle, y: end - notchDepth))
        path.addLine(to: CGPoint(x: leftEdge.x, y: end))
        path.closeSubpath()
        return path.applying(ribbonFall(drop: drop))
    }

    private static func ribbonFall(drop: Double) -> CGAffineTransform {
        CGAffineTransform(translationX: 0, y: -(1 - drop) * (boardFront + ribbonTail + 4))
    }

    // MARK: - Geometry

    /// One half of the book as solid faces, swung about the hinge by `angle`.
    /// `side` is -1 for the left half and 1 for the right; `dx` runs outward
    /// from the spine in that direction.
    private struct Half {
        let side: CGFloat
        let angle: Double

        var boardWidth: CGFloat { BookmarkLoader.boardWidth }
        var blockWidth: CGFloat { BookmarkLoader.boardWidth - BookmarkLoader.blockInset }
        var blockBack: CGFloat { BookmarkLoader.boardBack + BookmarkLoader.blockInset }
        var blockFrontZ: CGFloat { BookmarkLoader.boardFront - BookmarkLoader.blockInset }
        var boardHeight: CGFloat { BookmarkLoader.boardThickness }
        var pageHeight: CGFloat { BookmarkLoader.boardThickness + BookmarkLoader.blockThickness }

        /// Rotates an across/up pair about the hinge. The hinge sits at the
        /// top of the page block, the way a spine flexes, so the swung half
        /// lands on top of the other rather than through it.
        private func swing(dx: CGFloat, h: CGFloat) -> (x: CGFloat, h: CGFloat) {
            let c = CGFloat(cos(angle))
            let s = CGFloat(sin(angle))
            let ax = side * dx
            let ah = h - pageHeight
            return (ax * c - ah * s, ax * s + ah * c + pageHeight)
        }

        /// Projects a point onto the screen.
        func point(dx: CGFloat, z: CGFloat, h: CGFloat) -> CGPoint {
            let r = swing(dx: dx, h: h)
            return CGPoint(x: BookmarkLoader.spineX + r.x - BookmarkLoader.lean * r.h, y: z - r.h)
        }

        /// Whether a face with this across/up normal, swung with the half,
        /// faces the viewer, who looks from the front, above and the right.
        func visible(nx: CGFloat, nh: CGFloat) -> Bool {
            let c = CGFloat(cos(angle))
            let s = CGFloat(sin(angle))
            let ax = side * nx
            let rx = ax * c - nh * s
            let rh = ax * s + nh * c
            return BookmarkLoader.lean * rx + rh > 0.001
        }

        func quad(_ a: (CGFloat, CGFloat, CGFloat), _ b: (CGFloat, CGFloat, CGFloat),
                  _ c: (CGFloat, CGFloat, CGFloat), _ d: (CGFloat, CGFloat, CGFloat)) -> Path {
            var path = Path()
            path.move(to: point(dx: a.0, z: a.1, h: a.2))
            path.addLine(to: point(dx: b.0, z: b.1, h: b.2))
            path.addLine(to: point(dx: c.0, z: c.1, h: c.2))
            path.addLine(to: point(dx: d.0, z: d.1, h: d.2))
            path.closeSubpath()
            return path
        }

        var boardTop: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront, h = boardHeight
            return quad((0, b, h), (boardWidth, b, h), (boardWidth, f, h), (0, f, h))
        }

        var boardOutside: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront
            return quad((0, b, 0), (boardWidth, b, 0), (boardWidth, f, 0), (0, f, 0))
        }

        /// The outside of the board dropped straight down onto the page level,
        /// the patch of page it is about to cover.
        var boardShadow: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront
            var path = Path()
            for (dx, z) in [(0, b), (boardWidth, b), (boardWidth, f), (0, f)] as [(CGFloat, CGFloat)] {
                let r = swing(dx: dx, h: 0)
                let flat = CGPoint(
                    x: BookmarkLoader.spineX + r.x - BookmarkLoader.lean * pageHeight,
                    y: z - pageHeight
                )
                if path.isEmpty { path.move(to: flat) } else { path.addLine(to: flat) }
            }
            path.closeSubpath()
            return path
        }

        var boardFront: Path {
            let f = BookmarkLoader.boardFront, h = boardHeight
            return quad((0, f, 0), (boardWidth, f, 0), (boardWidth, f, h), (0, f, h))
        }

        var boardSide: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront, h = boardHeight
            return quad((boardWidth, b, 0), (boardWidth, f, 0), (boardWidth, f, h), (boardWidth, b, h))
        }

        var pageFace: Path {
            quad((0, blockBack, pageHeight), (blockWidth, blockBack, pageHeight),
                 (blockWidth, blockFrontZ, pageHeight), (0, blockFrontZ, pageHeight))
        }

        var blockFront: Path {
            quad((0, blockFrontZ, boardHeight), (blockWidth, blockFrontZ, boardHeight),
                 (blockWidth, blockFrontZ, pageHeight), (0, blockFrontZ, pageHeight))
        }

        var blockSide: Path {
            quad((blockWidth, blockBack, boardHeight), (blockWidth, blockFrontZ, boardHeight),
                 (blockWidth, blockFrontZ, pageHeight), (blockWidth, blockBack, pageHeight))
        }

        /// Two faint lines along the block's front edge, the pages as layers.
        var blockFrontLines: Path {
            var path = Path()
            for h in layerHeights {
                path.move(to: point(dx: 1.5, z: blockFrontZ, h: h))
                path.addLine(to: point(dx: blockWidth - 1.5, z: blockFrontZ, h: h))
            }
            return path
        }

        /// The same lines carried round the fore-edge.
        var blockSideLines: Path {
            var path = Path()
            for h in layerHeights {
                path.move(to: point(dx: blockWidth, z: blockBack + 1.5, h: h))
                path.addLine(to: point(dx: blockWidth, z: blockFrontZ - 1.5, h: h))
            }
            return path
        }

        private var layerHeights: [CGFloat] {
            [0.35, 0.68].map { boardHeight + (pageHeight - boardHeight) * $0 }
        }

        /// A few lines of text on the page, the last one short like a paragraph end.
        var textLines: Path {
            var path = Path()
            for (index, z) in BookmarkLoader.textRows.enumerated() {
                let near: CGFloat = 7
                let far = blockWidth - 7
                let isLast = index == BookmarkLoader.textRows.count - 1
                let end = isLast ? near + (far - near) * 0.55 : far
                path.move(to: point(dx: near, z: z, h: pageHeight))
                path.addLine(to: point(dx: end, z: z, h: pageHeight))
            }
            return path
        }

        /// The tooled frame on the outside of the board.
        var tooling: Path {
            let b = BookmarkLoader.boardBack + 6, f = BookmarkLoader.boardFront - 6
            return quad((6, b, 0), (boardWidth - 6, b, 0), (boardWidth - 6, f, 0), (6, f, 0))
        }

        /// Metal corner pieces at the two fore-edge corners of the board.
        var corners: Path {
            let arm: CGFloat = 9
            var path = Path()
            for (z, dir) in [(BookmarkLoader.boardBack, 1.0), (BookmarkLoader.boardFront, -1.0)] as [(CGFloat, CGFloat)] {
                path.move(to: point(dx: boardWidth, z: z, h: 0))
                path.addLine(to: point(dx: boardWidth - arm, z: z, h: 0))
                path.addLine(to: point(dx: boardWidth, z: z + arm * dir, h: 0))
                path.closeSubpath()
            }
            return path
        }

        // The spine is stretched between the left hinge, fixed at the table,
        // and this half's hinge, wherever the swing has carried it.

        var spine: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront
            let hinge = swing(dx: 0, h: 0)
            var path = Path()
            path.move(to: tablePoint(z: b))
            path.addLine(to: point(dx: 0, z: b, h: 0))
            path.addLine(to: point(dx: 0, z: f, h: 0))
            path.addLine(to: tablePoint(z: f))
            path.closeSubpath()
            _ = hinge
            return path
        }

        /// The raised bands of a medieval binding, four across the spine.
        var spineBands: Path {
            let b = BookmarkLoader.boardBack, f = BookmarkLoader.boardFront
            var path = Path()
            for t in [0.2, 0.4, 0.6, 0.8] as [CGFloat] {
                let z = b + (f - b) * t
                path.move(to: tablePoint(z: z))
                path.addLine(to: point(dx: 0, z: z, h: 0))
            }
            return path
        }

        /// Whether the spine faces the viewer: it does once the swung hinge
        /// is high enough above the table for the face between them to tilt
        /// towards the right rather than down.
        var spineVisible: Bool {
            let hinge = swing(dx: 0, h: 0)
            // Normal of the face from (0, 0) to (hinge.x, hinge.h), pointing right.
            let nx = hinge.h
            let nh = -hinge.x
            return BookmarkLoader.lean * nx + nh > 0.001 && hinge.h > 0.5
        }

        private func tablePoint(z: CGFloat) -> CGPoint {
            CGPoint(x: BookmarkLoader.spineX, y: z)
        }
    }
}

#Preview("Loader") {
    BookmarkLoader()
}

#Preview("Poses") {
    let poses: [BookmarkLoader.Pose] = [
        .init(ribbonDrop: 0, closing: 0),
        .init(ribbonDrop: 1, closing: 0),
        .init(ribbonDrop: 1, closing: 0.35),
        .init(ribbonDrop: 1, closing: 0.7),
        .init(ribbonDrop: 1, closing: 1),
    ]
    HStack(spacing: 16) {
        ForEach(Array(poses.enumerated()), id: \.offset) { _, pose in
            Canvas { ctx, size in
                BookmarkLoader.draw(&ctx, canvasSize: size, pose: pose)
            }
            .frame(width: 132, height: 142)
        }
    }
    .padding()
}
