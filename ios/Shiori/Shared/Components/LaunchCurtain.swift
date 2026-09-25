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
    /// Shuffled once per launch, so the rows do not open on the same covers.
    @State private var covers = Self.bundledCovers.shuffled()
    @State private var start = Date()
    @State private var coversShown = false

    var body: some View {
        ZStack {
            // The asset the system launch screen is painted with too: the
            // icon's cream by day, a warm ink at night.
            Color.launchBackground
            if !covers.isEmpty {
                TimelineView(.animation(paused: reduceMotion)) { context in
                    let elapsed = reduceMotion ? 0 : context.date.timeIntervalSince(start)
                    Canvas { ctx, size in
                        Self.drawRows(&ctx, size: size, covers: covers, elapsed: elapsed)
                    }
                }
                .opacity(coversShown ? 1 : 0)
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
        .onAppear {
            // The system launch screen is the bare colour: the covers fade in
            // over it rather than popping.
            withAnimation(.easeOut(duration: 0.8)) { coversShown = true }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Shiori"))
    }

    // MARK: - Covers

    /// Everything named `launch-cover-*.jpg` in the bundle, in file order.
    static let bundledCovers: [UIImage] = (Bundle.main.paths(
        forResourcesOfType: "jpg", inDirectory: nil
    ))
    .filter { ($0 as NSString).lastPathComponent.hasPrefix("launch-cover-") }
    .sorted()
    .compactMap(UIImage.init(contentsOfFile:))

    /// A cover's size on screen, in points: a paperback's proportions.
    private static let coverSize = CGSize(width: 96, height: 146)
    private static let spacing: CGFloat = 14
    /// How far the rows lean off the horizontal.
    private static let tilt = Angle.degrees(-12)
    /// Points per second; each row runs a little faster or slower than this.
    private static let speed: Double = 26

    /// Lays out one frame of the drift. The rows are drawn about the centre of
    /// the screen and turned by `tilt`, wide and many enough that the turned
    /// band still covers every corner.
    static func drawRows(
        _ ctx: inout GraphicsContext, size: CGSize, covers: [UIImage], elapsed: TimeInterval
    ) {
        let diagonal = (size.width * size.width + size.height * size.height).squareRoot()
        let pitch = coverSize.height + spacing
        let rowCount = Int((diagonal / pitch).rounded(.up)) + 1
        let step = coverSize.width + spacing
        // A row repeats its covers end to end; one repeat is at least as wide
        // as the diagonal so the seam never shows.
        let perStrip = max(covers.count, Int((diagonal / step).rounded(.up)) + 1)
        let stripWidth = CGFloat(perStrip) * step
        let images = covers.map { ctx.resolve(Image(uiImage: $0)) }
        let strides = Self.strides(for: images.count)

        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: tilt)

        for row in 0..<rowCount {
            let y = (CGFloat(row) - CGFloat(rowCount) / 2) * pitch - coverSize.height / 2
            // Every row its own pace and direction, and its own first cover,
            // so the columns never line up.
            let pace = speed * (0.8 + 0.4 * Double((row * 7) % 5) / 4)
            let travel = CGFloat(elapsed * pace).truncatingRemainder(dividingBy: stripWidth)
            let shift = row.isMultiple(of: 2) ? -travel : travel - stripWidth
            let firstCover = row * 5
            // Each row also walks the covers with its own stride, so two rows
            // never show the same run of neighbours. A stride sharing no factor
            // with the count still visits every cover.
            let stride = strides[row % strides.count]
            var x = -diagonal / 2 + shift
            var index = 0
            while x < diagonal / 2 {
                if x + coverSize.width > -diagonal / 2 {
                    let rect = CGRect(origin: CGPoint(x: x, y: y), size: coverSize)
                    let image = images[(firstCover + (index % perStrip) * stride) % images.count]
                    var cover = ctx
                    cover.clip(to: Path(roundedRect: rect, cornerRadius: 5))
                    cover.draw(image, in: rect)
                }
                x += step
                index += 1
            }
        }
    }

    /// The steps coprime with `count`, smallest first: 1 is always one.
    private static func strides(for count: Int) -> [Int] {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        return (1...max(count - 1, 1)).filter { gcd($0, count) == 1 }
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
