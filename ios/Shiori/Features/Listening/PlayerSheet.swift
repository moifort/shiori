import SwiftUI

extension EnvironmentValues {
    /// Closes the player the way a pull-down does: down to the foot of the
    /// screen, then into its pill. Nil outside the player.
    @Entry var closePlayer: (() -> Void)?
}

/// The full-screen player's own sheet, in place of the system's: it grows out
/// of the pill over the tab bar, and pulled down it follows the thumb whole,
/// without shrinking; let go far enough, it slides to the foot of the screen
/// and only then draws itself in, rounding, into the pill.
///
/// `pillFrame` is the pill's frame in the window. The content is laid out at
/// the sheet's full size whatever the animation does, so nothing reflows.
struct PlayerSheet<Content: View, Backdrop: View, Pill: View>: View {
    let pillFrame: CGRect
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

    private static var cornerRadius: CGFloat { 38 }
    private static var topGap: CGFloat { 8 }

    var body: some View {
        GeometryReader { proxy in
            let insets = proxy.safeAreaInsets
            let screen = CGSize(
                width: proxy.size.width + insets.leading + insets.trailing,
                height: proxy.size.height + insets.top + insets.bottom
            )
            let top = insets.top + Self.topGap
            let sheetHeight = screen.height - top
            let pill = pillFrame.isEmpty ? fallbackPill(in: screen, bottom: insets.bottom) : pillFrame
            let sheet = CGRect(x: 0, y: top + pull, width: screen.width, height: sheetHeight)
            let frame = mix(sheet, pill, morph)
            let radius = Self.cornerRadius + (pill.height / 2 - Self.cornerRadius) * morph

            ZStack(alignment: .topLeading) {
                Color.black
                    .opacity(0.4 * Double(1 - morph) * Double(max(0, 1 - pull / sheetHeight)))
                    .allowsHitTesting(false)

                ZStack(alignment: .topLeading) {
                    backdrop()
                        .frame(width: frame.width, height: frame.height)
                        .opacity(fade(morph, from: 0.6, to: 1, out: true))
                    content()
                        .safeAreaPadding(.bottom, insets.bottom)
                        .frame(width: screen.width, height: sheetHeight)
                        .scaleEffect(frame.width / screen.width, anchor: .topLeading)
                        .opacity(fade(morph, from: 0, to: 0.35, out: true))
                        .allowsHitTesting(morph == 0 && !isClosing)
                    grabber
                        .frame(width: frame.width)
                        .opacity(fade(morph, from: 0, to: 0.2, out: true))
                    self.pill()
                        .frame(width: pill.width, height: pill.height)
                        .opacity(fade(morph, from: 0.55, to: 1, out: false))
                        .allowsHitTesting(false)
                }
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .shadow(color: .black.opacity(0.3 * Double(1 - morph)), radius: 20, y: -4)
                .offset(x: frame.minX, y: frame.minY)
                .gesture(pullDown(sheetHeight: sheetHeight, toPill: pill.minY - top))
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            // Laid out over the whole screen, in the window's coordinates the
            // pill's frame is given in; the content gets only the bottom inset.
            .ignoresSafeArea()
            .environment(\.closePlayer) { close(toPill: pill.minY - top) }
            .accessibilityAction(.escape) { close(toPill: pill.minY - top) }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.45, bounce: 0.12)) { morph = 0 }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.5))
            .frame(width: 36, height: 5)
            .padding(.top, 6)
            .accessibilityHidden(true)
    }

    /// Down only: the sheet follows the thumb whole. Let go past a quarter of
    /// the screen, or flicked, it closes; short of that it climbs back.
    private func pullDown(sheetHeight: CGFloat, toPill: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .global)
            .onChanged { value in
                guard !isClosing, morph == 0 else { return }
                pull = max(0, value.translation.height)
            }
            .onEnded { value in
                guard !isClosing, morph == 0 else { return }
                let projected = max(0, value.predictedEndTranslation.height)
                if pull > sheetHeight / 4 || projected > sheetHeight / 2 {
                    close(toPill: toPill)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) { pull = 0 }
                }
            }
    }

    /// Down to the pill's height, then into it.
    private func close(toPill: CGFloat) {
        guard !isClosing else { return }
        isClosing = true
        withAnimation(.easeOut(duration: 0.22)) {
            pull = max(pull, toPill)
        } completion: {
            withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                morph = 1
            } completion: {
                onClosed()
            }
        }
    }

    /// Where a pill sits over the tab bar when the system has not drawn one.
    private func fallbackPill(in screen: CGSize, bottom: CGFloat) -> CGRect {
        CGRect(x: 21, y: screen.height - bottom - 120, width: screen.width - 42, height: 56)
    }

    private func mix(_ from: CGRect, _ to: CGRect, _ progress: CGFloat) -> CGRect {
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        return CGRect(
            x: lerp(from.minX, to.minX),
            y: lerp(from.minY, to.minY),
            width: lerp(from.width, to.width),
            height: lerp(from.height, to.height)
        )
    }

    /// An opacity along the morph: fading out between `from` and `to`, or in.
    private func fade(_ progress: CGFloat, from start: CGFloat, to end: CGFloat, out: Bool) -> Double {
        let t = Double(min(1, max(0, (progress - start) / (end - start))))
        return out ? 1 - t : t
    }
}
