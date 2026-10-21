import SwiftUI

extension EnvironmentValues {
    /// Where an open iPhone Duo folds, as an x in the window's coordinates:
    /// the middle of its inner screen. Nil on a phone, on the Duo's outer
    /// screen and whenever the hinge is closed. A page laying itself out in
    /// two columns splits them there, so no card is drawn across the crease.
    @Entry var foldLine: CGFloat?
}

extension View {
    /// Hands the views below where the screen folds, from the hinge iOS 27.1
    /// reports. Applied once, at the root of the window.
    func readsDeviceFold() -> some View {
        modifier(DeviceFoldReader())
    }
}

private struct DeviceFoldReader: ViewModifier {
    /// The middle of the window, safe areas included: where the fold is.
    @State private var middle: CGFloat?
    /// Whether the hinge is open, fully or partly — a book held half open
    /// folds in the same place as one laid flat.
    @State private var isOpen = false

    func body(content: Content) -> some View {
        content
            .environment(\.foldLine, isOpen ? middle : nil)
            // The content stops at the safe areas — the Duo keeps the clock
            // in a column on its right — so they are added back on each side.
            .onGeometryChange(for: CGFloat.self) { proxy in
                let frame = proxy.frame(in: .global)
                let insets = proxy.safeAreaInsets
                return (frame.minX - insets.leading + frame.maxX + insets.trailing) / 2
            } action: { middle = $0 }
            .modifier(HingeObserver(isOpen: $isOpen))
    }
}

/// The hinge, read where the SDK knows it: Xcode 27.1 and later. An older SDK
/// builds an app that sees no fold, and lays the Duo out as a wide screen.
private struct HingeObserver: ViewModifier {
    @Binding var isOpen: Bool

    func body(content: Content) -> some View {
        #if canImport(SwiftUICore, _version: 8.0.85)
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                guard let hinge = context.hinge else {
                    isOpen = false
                    return
                }
                isOpen = hinge.status == .fullyOpen || hinge.status == .partiallyOpen
            }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
