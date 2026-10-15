import SwiftUI

/// The app opening: the icon in the middle, and behind it rows of covers
/// drifting across the screen, alternately left and right, on a slant. It stays
/// down while the app finds out where to open, then fades away on whatever is
/// ready underneath.
///
/// The covers are the ones shipped in `LaunchCovers/` (see
/// `scripts/launch-covers.ts`); with none, the icon stands on its own.
struct LaunchCurtain: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Decoded off the main thread, then faded in: empty until they are ready.
    @State private var covers: [CGImage] = []

    var body: some View {
        ZStack {
            // The asset the system launch screen is painted with too: the
            // icon's cream by day, a warm ink at night.
            Color.launchBackground
            CoverDrift(covers: covers, moving: !reduceMotion)
                // The system launch screen is the bare colour: the covers fade
                // in over it rather than popping.
                .opacity(covers.isEmpty ? 0 : 1)
                .animation(.easeOut(duration: 0.8), value: covers.isEmpty)
            if !covers.isEmpty {
                // A light pool of the background behind the icon, so it does
                // not fight the covers for the eye. Veiled, not blanked: the
                // covers still show through.
                RadialGradient(
                    colors: [.launchBackground.opacity(0.7), .launchBackground.opacity(0.4), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
            }
            RibbonMark(motion: .once, size: 140)
        }
        .ignoresSafeArea()
        .task {
            covers = await Task.detached(priority: .userInitiated) { Self.loadCovers() }.value
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Shiori"))
    }

    /// Everything named `launch-cover-*.jpg` in the bundle, decoded now rather
    /// than on first draw — which would land in the middle of the ribbon's
    /// drop — and shuffled, so every launch deals the rows different covers.
    nonisolated private static func loadCovers() -> [CGImage] {
        Bundle.main.paths(forResourcesOfType: "jpg", inDirectory: nil)
            .filter { ($0 as NSString).lastPathComponent.hasPrefix("launch-cover-") }
            .compactMap { UIImage(contentsOfFile: $0)?.preparingForDisplay()?.cgImage }
            .shuffled()
    }
}

/// The rows of covers, as Core Animation layers. Laid out once, then moved by
/// the render server: the drift costs the main thread nothing per frame, so it
/// keeps its pace while the app is busy starting, and the ribbon keeps its own.
private struct CoverDrift: UIViewRepresentable {
    let covers: [CGImage]
    let moving: Bool

    func makeUIView(context: Context) -> CoverDriftView {
        CoverDriftView()
    }

    func updateUIView(_ view: CoverDriftView, context: Context) {
        view.show(covers, moving: moving)
    }
}

private final class CoverDriftView: UIView {
    /// A cover's size on screen, in points: a paperback's proportions.
    private static let coverSize = CGSize(width: 96, height: 146)
    private static let spacing: CGFloat = 14
    /// How far the rows lean off the horizontal, in radians.
    private static let tilt: CGFloat = -12 * .pi / 180
    /// Points per second; each row runs a little faster or slower than this.
    private static let speed: CGFloat = 26

    private var covers: [CGImage] = []
    private var moving = true
    private var builtFor: CGSize = .zero

    func show(_ covers: [CGImage], moving: Bool) {
        guard covers != self.covers || moving != self.moving else { return }
        self.covers = covers
        self.moving = moving
        builtFor = .zero
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.size != builtFor, bounds.width > 0, !covers.isEmpty else { return }
        builtFor = bounds.size
        build()
    }

    /// Lays the rows out about the centre and turns them by `tilt`, wide and
    /// many enough that the turned band still covers every corner. Each row is
    /// one strip of covers, repeated end to end, slid by exactly one repeat and
    /// started over: the seam never shows.
    ///
    /// The covers are dealt out between the rows, so a cover drifting in one row
    /// shows up in no other — only when there are fewer covers than rows do
    /// rows have to share.
    private func build() {
        layer.sublayers?.forEach { $0.removeFromSuperlayer() }

        let size = Self.coverSize
        let diagonal = (bounds.width * bounds.width + bounds.height * bounds.height).squareRoot()
        let pitch = size.height + Self.spacing
        let rowCount = Int((diagonal / pitch).rounded(.up)) + 1
        let step = size.width + Self.spacing
        let hands = Self.deal(covers, into: rowCount)
        let across = Int((diagonal / step).rounded(.up)) + 1

        let band = CALayer()
        band.bounds = CGRect(x: 0, y: 0, width: diagonal, height: CGFloat(rowCount) * pitch)
        band.position = CGPoint(x: bounds.midX, y: bounds.midY)
        band.setAffineTransform(CGAffineTransform(rotationAngle: Self.tilt))
        layer.addSublayer(band)

        let scale = window?.screen.scale ?? 3
        for row in 0..<rowCount {
            let hand = hands[row % hands.count]
            // One repeat is a whole number of turns through the row's covers,
            // so the seam does not break their order, and at least as wide as
            // the diagonal. A strip carries a repeat plus a screen's worth, so
            // it covers the band all the way through its slide.
            let perStrip = hand.count * Int((CGFloat(across) / CGFloat(hand.count)).rounded(.up))
            let repeatWidth = CGFloat(perStrip) * step
            let perRow = perStrip + across

            let strip = CALayer()
            strip.anchorPoint = .zero
            strip.bounds = CGRect(x: 0, y: 0, width: CGFloat(perRow) * step, height: size.height)
            for index in 0..<perRow {
                let cover = CALayer()
                cover.frame = CGRect(x: CGFloat(index) * step, y: 0, width: size.width, height: size.height)
                cover.contents = hand[index % hand.count]
                cover.contentsGravity = .resizeAspectFill
                cover.contentsScale = scale
                cover.cornerRadius = 5
                cover.cornerCurve = .continuous
                cover.masksToBounds = true
                strip.addSublayer(cover)
            }

            // Alternately left and right, each row at its own pace.
            let leftward = row.isMultiple(of: 2)
            let from = CGPoint(x: leftward ? 0 : -repeatWidth, y: CGFloat(row) * pitch)
            let to = CGPoint(x: leftward ? -repeatWidth : 0, y: from.y)
            strip.position = from
            band.addSublayer(strip)

            guard moving else { continue }
            let pace = Self.speed * (0.8 + 0.4 * CGFloat((row * 7) % 5) / 4)
            let slide = CABasicAnimation(keyPath: "position")
            slide.fromValue = NSValue(cgPoint: from)
            slide.toValue = NSValue(cgPoint: to)
            slide.duration = repeatWidth / pace
            slide.repeatCount = .infinity
            slide.isRemovedOnCompletion = false
            strip.add(slide, forKey: "drift")
        }
    }

    /// The covers dealt round like cards, one hand per row: as many hands as
    /// rows, or as covers when there are fewer, and no cover in two hands.
    private static func deal(_ covers: [CGImage], into rows: Int) -> [[CGImage]] {
        let count = min(rows, covers.count)
        return (0..<count).map { hand in
            Swift.stride(from: hand, to: covers.count, by: count).map { covers[$0] }
        }
    }
}

extension View {
    /// Covers the view with the launch curtain until `ready`, then fades it out.
    /// It stays down for at least the icon's entrance, so a fast launch still
    /// shows the ribbon land rather than flashing it.
    func launchCurtain(until ready: Bool) -> some View {
        modifier(LaunchCurtainModifier(ready: ready))
    }
}

private struct LaunchCurtainModifier: ViewModifier {
    let ready: Bool

    @State private var entranceOver = false
    @State private var faded = false
    @State private var gone = false

    /// Long enough for the ribbon to drop and swing.
    private static let minimumShown: Duration = .seconds(2)

    func body(content: Content) -> some View {
        content
            .overlay {
                if !gone {
                    LaunchCurtain()
                        .opacity(faded ? 0 : 1)
                }
            }
            .task {
                try? await Task.sleep(for: Self.minimumShown)
                entranceOver = true
            }
            .onChange(of: ready && entranceOver, initial: true) { _, canFade in
                guard canFade, !faded else { return }
                withAnimation(.easeInOut(duration: 0.7)) {
                    faded = true
                } completion: {
                    gone = true
                }
            }
    }
}

#Preview {
    Text(verbatim: "Library")
        .launchCurtain(until: false)
}
