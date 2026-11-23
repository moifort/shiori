import SwiftUI

extension EnvironmentValues {
    /// Closes the player the way a pull-down does: down to the foot of the
    /// screen, then into its pill. Nil outside the player.
    @Entry var closePlayer: (() -> Void)?
}

/// Where the player's big cover sits in the window, for the sheet to fly it
/// into the pill's round cover.
struct PlayerArtworkFrameKey: PreferenceKey {
    static let defaultValue = CGRect.zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if !next.isEmpty { value = next }
    }
}

/// The full-screen player's own sheet, in place of the system's, as in Music:
/// pulled down by its tab or anywhere on it, it follows the thumb whole,
/// without shrinking; let go far enough, it slides down to the pill and draws
/// itself in around its cover, which flies into the pill's round cover while
/// the sheet narrows and rounds into the pill's glass. Opening runs the same
/// way back, out of the pill.
///
/// `pillFrame` is the pill's frame in the window. The content is laid out at
/// the sheet's full size whatever the animation does, so nothing reflows.
struct PlayerSheet<Content: View, Backdrop: View, Pill: View>: View {
    let pillFrame: CGRect
    let coverURL: URL?
    /// Called once the sheet has gone back into its pill.
    let onClosed: () -> Void
    @ViewBuilder let content: () -> Content
    @ViewBuilder let backdrop: () -> Backdrop
    @ViewBuilder let pill: () -> Pill

    /// 1 in the pill, 0 open.
    @State private var morph: CGFloat = 1
    /// How far the thumb has pulled the sheet down.
    @State private var pull: CGFloat = 0
    @State private var isClosing = false
    /// The big cover, measured while the sheet is open and still.
    @State private var artworkFrame: CGRect = .zero

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let screen = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            let geometry = PlayerSheetGeometry(
                screen: screen,
                insets: insets,
                pill: pillFrame.isEmpty ? PlayerSheetGeometry.fallbackPill(in: screen, bottom: insets.bottom) : pillFrame,
                artwork: artworkFrame
            )
            PlayerSheetLayer(
                morph: morph,
                pull: pull,
                geometry: geometry,
                coverURL: coverURL,
                isInteractive: morph == 0 && !isClosing,
                content: content,
                backdrop: backdrop,
                pill: pill
            )
            .gesture(pullDown(geometry))
            .onPreferenceChange(PlayerArtworkFrameKey.self) { frame in
                // Only the cover at rest: the sheet moves it while it slides.
                guard morph == 0, pull == 0, !isClosing, !frame.isEmpty else { return }
                artworkFrame = frame
            }
            .environment(\.closePlayer) { close(geometry) }
            .accessibilityAction(.escape) { close(geometry) }
        }
        .task {
            // One layout pass first, so the cover is measured before it flies.
            await Task.yield()
            withAnimation(.spring(duration: 0.5, bounce: 0.12)) { morph = 0 }
        }
    }

    /// Down only, from the tab or anywhere on the sheet: it follows the thumb
    /// whole. Let go past a quarter of the screen, or flicked, it closes;
    /// short of that it climbs back.
    private func pullDown(_ geometry: PlayerSheetGeometry) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                guard !isClosing, morph == 0 else { return }
                pull = max(0, value.translation.height)
            }
            .onEnded { value in
                guard !isClosing, morph == 0 else { return }
                let projected = max(0, value.predictedEndTranslation.height)
                if pull > geometry.sheetHeight / 4 || projected > geometry.sheetHeight / 2 {
                    close(geometry)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) { pull = 0 }
                }
            }
    }

    /// Down to the pill, then into it.
    private func close(_ geometry: PlayerSheetGeometry) {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(.easeIn(duration: 0.2)) {
            pull = max(pull, geometry.pullToPill)
        } completion: {
            withAnimation(.spring(duration: 0.42, bounce: 0.08)) {
                morph = 1
            } completion: {
                onClosed()
            }
        }
    }
}

/// The fixed points of the sheet's trip, in the window's coordinates.
struct PlayerSheetGeometry {
    let screen: CGSize
    let insets: EdgeInsets
    let pill: CGRect
    /// The big cover with the sheet open and still; empty before it is measured.
    let artwork: CGRect

    static let cornerRadius: CGFloat = 38
    static let topGap: CGFloat = 8

    var top: CGFloat { insets.top + Self.topGap }
    var sheetHeight: CGFloat { screen.height - top }
    /// The pull that brings the big cover down level with the pill, from
    /// where it draws itself into it; the sheet's top when it is not measured.
    var pullToPill: CGFloat { max(0, pill.minY - (artwork.isEmpty ? top : artwork.minY)) }
    /// The pill's round cover, at its leading end.
    var pillCover: CGRect { CGRect(x: pill.minX, y: pill.minY, width: pill.height, height: pill.height) }

    /// Where a pill sits over the tab bar when the system has not drawn one.
    static func fallbackPill(in screen: CGSize, bottom: CGFloat) -> CGRect {
        CGRect(x: 21, y: screen.height - bottom - 120, width: screen.width - 42, height: 56)
    }
}

/// The sheet drawn at one point of its trip. Animatable, so every frame is
/// drawn from the morph and the pull of that frame: the fades and the flying
/// cover follow their own curves rather than a straight line between the ends.
private struct PlayerSheetLayer<Content: View, Backdrop: View, Pill: View>: View, @MainActor Animatable {
    var morph: CGFloat
    var pull: CGFloat
    let geometry: PlayerSheetGeometry
    let coverURL: URL?
    let isInteractive: Bool
    @ViewBuilder let content: () -> Content
    @ViewBuilder let backdrop: () -> Backdrop
    @ViewBuilder let pill: () -> Pill

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(morph, pull) }
        set {
            morph = newValue.first
            pull = newValue.second
        }
    }

    var body: some View {
        let screen = geometry.screen
        let sheet = CGRect(x: 0, y: geometry.top + pull, width: screen.width, height: geometry.sheetHeight)
        // The sheet narrows on the way in a little ahead of the cover, so the
        // cover is never cut by its edges.
        let frame = mix(sheet, geometry.pill, ease(morph))
        let radius = mix(PlayerSheetGeometry.cornerRadius, geometry.pill.height / 2, ease(morph))
        let hasCover = !geometry.artwork.isEmpty

        ZStack(alignment: .topLeading) {
            Color.black
                .opacity(0.4 * Double(1 - morph) * Double(max(0, 1 - pull / geometry.sheetHeight)))
                .allowsHitTesting(false)

            ZStack(alignment: .topLeading) {
                backdrop()
                    .frame(width: frame.width, height: frame.height)
                    .opacity(fade(morph, from: 0.55, to: 0.95, out: true))
                content()
                    .safeAreaPadding(.bottom, geometry.insets.bottom)
                    .frame(width: screen.width, height: geometry.sheetHeight)
                    .scaleEffect(frame.width / screen.width, anchor: .topLeading)
                    .opacity(fade(morph, from: 0, to: 0.25, out: true))
                    .allowsHitTesting(isInteractive)
                grabber(width: frame.width)
                    .opacity(fade(morph, from: 0, to: 0.15, out: true))
                pill()
                    .frame(width: geometry.pill.width, height: geometry.pill.height)
                    .opacity(fade(morph, from: 0.6, to: 1, out: false))
                    .allowsHitTesting(false)
            }
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            // The whole sheet takes the thumb, its empty parts and its tab
            // included, not only what is drawn on it.
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: .black.opacity(0.3 * Double(1 - morph)), radius: 20, y: -4)
            .offset(x: frame.minX, y: frame.minY)

            if hasCover, morph > 0 {
                flyingCover
            }
        }
        .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        // Laid out over the whole screen, in the window's coordinates the
        // pill's frame is given in; the content gets only the bottom inset.
        .ignoresSafeArea()
    }

    /// The big cover, lifted off the sheet: it flies from its place on the
    /// sheet into the pill's round cover, rounding on the way.
    private var flyingCover: some View {
        let start = geometry.artwork.offsetBy(dx: 0, dy: pull)
        let end = geometry.pillCover
        let rect = mix(start, end, morph)
        let side = start.width
        let scale = rect.width / side
        return PlayerArtwork(url: coverURL, size: side, cornerRadius: 0)
            .clipShape(RoundedRectangle(cornerRadius: mix(12 / 1, side / 2, ease(morph)), style: .continuous))
            .shadow(color: .black.opacity(0.35 * Double(1 - morph)), radius: 20, y: 14)
            .scaleEffect(scale, anchor: .topLeading)
            .offset(x: rect.minX, y: rect.minY)
            .opacity(fade(morph, from: 0.9, to: 1, out: true))
            .allowsHitTesting(false)
    }

    private func grabber(width: CGFloat) -> some View {
        Capsule()
            .fill(.white.opacity(0.5))
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .frame(width: width, height: 30, alignment: .top)
            .accessibilityHidden(true)
    }

    /// Ahead of the straight line at first, so the sheet closes in before the
    /// cover reaches its edges.
    private func ease(_ t: CGFloat) -> CGFloat { 1 - (1 - t) * (1 - t) }

    private func mix(_ from: CGFloat, _ to: CGFloat, _ t: CGFloat) -> CGFloat { from + (to - from) * t }

    private func mix(_ from: CGRect, _ to: CGRect, _ t: CGFloat) -> CGRect {
        CGRect(
            x: mix(from.minX, to.minX, t),
            y: mix(from.minY, to.minY, t),
            width: mix(from.width, to.width, t),
            height: mix(from.height, to.height, t)
        )
    }

    /// An opacity along the morph: fading out between `from` and `to`, or in.
    private func fade(_ t: CGFloat, from start: CGFloat, to end: CGFloat, out: Bool) -> Double {
        let progress = Double(min(1, max(0, (t - start) / (end - start))))
        return out ? 1 - progress : progress
    }
}
