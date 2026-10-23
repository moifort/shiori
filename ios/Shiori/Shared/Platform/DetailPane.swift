import SwiftUI

/// How the screen at the top of a detail closes, and so whether it draws a
/// Close button: a sheet's root and the detail column beside a page do, a
/// screen pushed on a stack leaves it to the system's Back button.
enum DetailClosing {
    /// The root of a sheet: Close dismisses the sheet.
    case sheet
    /// The root of the detail column beside the page that opened it, on an
    /// unfolded iPhone Duo: Close empties the column.
    case pane(@MainActor () -> Void)
    /// Pushed on a stack: Back closes it.
    case pushed

    /// Whether the screen draws its own Close button.
    var showsCloseButton: Bool {
        if case .pushed = self { false } else { true }
    }

    /// Closes the screen: empties the column it fills, or dismisses the sheet
    /// it roots or the stack entry it is.
    @MainActor
    func close(_ dismiss: DismissAction) {
        if case let .pane(empty) = self { empty() } else { dismiss() }
    }
}

extension EnvironmentValues {
    /// Set by whatever opens a detail: a sheet unless told otherwise, as
    /// every screen was presented before details were pushed.
    @Entry var detailClosing: DetailClosing = .sheet
}

extension View {
    /// The root of a sheet that hosts a detail screen. Needed only where the
    /// sheet is presented from a pushed screen, whose closing it would inherit.
    func closesAsSheet() -> some View {
        environment(\.detailClosing, .sheet)
    }

    /// A screen pushed with a plain `navigationDestination` or link: Back
    /// closes it, so it draws no Close button.
    func closesAsPushed() -> some View {
        environment(\.detailClosing, .pushed)
    }

    /// Pushes the screen an item opens on the enclosing stack, as Mail pushes a
    /// message on a phone: Back closes it, and `onClose` hears it was closed.
    func pushesDetail<Item: Identifiable, Destination: View>(
        item: Binding<Item?>,
        onClose: @escaping (Item) -> Void = { _ in },
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        modifier(PushedDetail(item: item, onClose: onClose, destination: destination))
    }
}

/// The push behind `pushesDetail`. The item last opened stays drawn while the
/// pop animates, once the binding has already let it go.
private struct PushedDetail<Item: Identifiable, Destination: View>: ViewModifier {
    @Binding var item: Item?
    let onClose: (Item) -> Void
    let destination: (Item) -> Destination
    @State private var shown: Item?

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: isPushed) {
                if let opened = item ?? shown {
                    destination(opened)
                        .environment(\.detailClosing, .pushed)
                }
            }
            .onChange(of: item?.id, initial: true) {
                if let item { shown = item }
            }
    }

    private var isPushed: Binding<Bool> {
        Binding(
            get: { item != nil },
            set: { pushed in
                guard !pushed, let closed = item else { return }
                item = nil
                onClose(closed)
            }
        )
    }
}

/// A page and the detail it opens, as Mail sets a message beside its inbox:
/// side by side in a regular width — an unfolded iPhone Duo, the split view
/// moving both columns to either side of the fold — and pushed over the page
/// in a compact one, a phone or a folded Duo. One state for both: folding with
/// a detail open pushes it, unfolding sets it back beside the page.
///
/// Without a detail the page has the whole width. Details opened from inside
/// the detail are pushed on its own stack, in either width.
struct DetailSplit<Item: Identifiable, Page: View, Detail: View>: View {
    @Binding var item: Item?
    /// Told when the reader closes the detail, by Back or by Close.
    var onClose: (Item) -> Void = { _ in }
    @ViewBuilder let page: () -> Page
    @ViewBuilder let detail: (Item) -> Detail

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .regular, let item {
            NavigationSplitView {
                page()
            } detail: {
                NavigationStack {
                    detail(item)
                }
                .id(item.id)
                .environment(\.detailClosing, .pane {
                    self.item = nil
                    onClose(item)
                })
            }
        } else {
            NavigationStack {
                page()
                    .pushesDetail(item: $item, onClose: onClose, destination: detail)
            }
        }
    }
}
