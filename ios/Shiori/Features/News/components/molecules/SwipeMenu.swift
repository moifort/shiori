import SwiftUI
import UIKit

/// A row that slides to the left under the finger and, past a short throw,
/// opens its menu where its "…" used to sit: the menu without the button. A
/// vertical drag is left to the scroll view, a tap to the row.
struct SwipeMenu: ViewModifier {
    /// Nil leaves the row still: nothing left to offer.
    let menu: UIMenu?

    /// How far the row followed the finger, negative to the left.
    @State private var offset: CGFloat = 0
    /// Bumped to open the menu.
    @State private var opens = 0

    /// The throw past which letting go opens the menu.
    private static let threshold: CGFloat = 56
    /// The farthest the row slides, past which it resists.
    private static let reach: CGFloat = 72

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                if menu != nil {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemBackground), in: .circle)
                        .padding(.trailing, 16)
                        .opacity(min(1, -offset / Self.threshold))
                        .accessibilityHidden(true)
                }
            }
            // Where the menu opens: the trailing edge, level with the row's
            // middle, as the "…" did.
            .overlay(alignment: .trailing) {
                if let menu {
                    MenuTrigger(menu: menu, opens: opens)
                        .frame(width: 1, height: 1)
                        .padding(.trailing, 24)
                        .accessibilityHidden(true)
                }
            }
            .gesture(
                LeftSwipe { translation in
                    guard menu != nil else { return }
                    offset = Self.resisted(min(0, translation))
                } ended: { translation in
                    if menu != nil, translation <= -Self.threshold { opens += 1 }
                    withAnimation(.spring(duration: 0.3)) { offset = 0 }
                }
            )
            .clipped()
            .accessibilityAction(named: Text("Plus d'actions")) {
                if menu != nil { opens += 1 }
            }
    }

    /// Free up to the reach, then a third of the way further.
    private static func resisted(_ translation: CGFloat) -> CGFloat {
        translation >= -reach ? translation : -reach + (translation + reach) / 3
    }
}

extension View {
    /// Slides the row to the left to open `menu`; nil keeps it still.
    func swipeOpensMenu(_ menu: UIMenu?) -> some View {
        modifier(SwipeMenu(menu: menu))
    }
}

/// An invisible button holding the menu, opened each time `opens` changes.
private struct MenuTrigger: UIViewRepresentable {
    let menu: UIMenu
    let opens: Int

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.showsMenuAsPrimaryAction = true
        button.isAccessibilityElement = false
        button.menu = menu
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = menu
        if context.coordinator.opens != opens {
            context.coordinator.opens = opens
            // After the update, once the button sits in the window again.
            DispatchQueue.main.async { button.performPrimaryAction() }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(opens: opens) }

    final class Coordinator {
        var opens: Int
        init(opens: Int) { self.opens = opens }
    }
}

/// A pan that starts only when the finger moves left more than it moves up or
/// down, so the feed keeps scrolling under a vertical drag.
private struct LeftSwipe: UIGestureRecognizerRepresentable {
    let changed: (CGFloat) -> Void
    let ended: (CGFloat) -> Void

    init(changed: @escaping (CGFloat) -> Void, ended: @escaping (CGFloat) -> Void) {
        self.changed = changed
        self.ended = ended
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func handleUIGestureRecognizerAction(_ pan: UIPanGestureRecognizer, context: Context) {
        let translation = pan.translation(in: pan.view).x
        switch pan.state {
        case .changed: changed(translation)
        case .ended, .cancelled, .failed: ended(pan.state == .ended ? translation : 0)
        default: break
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
            guard let pan = gesture as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return velocity.x < 0 && abs(velocity.x) > abs(velocity.y)
        }

        /// Beside the feed's own pan rather than against it: a scroll view
        /// claims a touch as soon as it moves, before this pan can begin. A
        /// horizontal throw moves the feed by nothing, a vertical one never
        /// starts this pan.
        func gestureRecognizer(
            _ gesture: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

extension UIMenu {
    /// What an Actualités row offers when slid: take the book, wish for it or
    /// await its recording. Nil once the reader holds the book and has no
    /// recording left to await, so the row stays still. A recording is never
    /// offered heard again.
    static func newsRow(
        format: BookFormat,
        owned: Bool,
        wished: Bool,
        awaited: Bool,
        onAdd: @escaping (CopiedStatus, BookFormat) async -> Void,
        onWish: @escaping () async -> Void,
        onAwait: @escaping (ReleaseFormat) -> Void
    ) -> UIMenu? {
        let awaitable: [ReleaseFormat] = format == .audiobook || awaited ? [] : [.audiobook]
        if owned, awaitable.isEmpty { return nil }
        return .bookAdd(
            formats: format.takenAs, owned: owned, awaitable: awaitable, wished: wished,
            onAdd: onAdd, onWish: onWish, onAwait: onAwait
        )
    }

    /// The items of `BookAddMenuItems`, for a menu UIKit opens: in each format
    /// the reader may take the book in, onto the pile or among the books read;
    /// onto the wishlist; its edition in the app's language awaited.
    static func bookAdd(
        formats: [BookFormat],
        owned: Bool,
        awaitable: [ReleaseFormat],
        wished: Bool,
        onAdd: @escaping (CopiedStatus, BookFormat) async -> Void,
        onWish: @escaping () async -> Void,
        onAwait: @escaping (ReleaseFormat) -> Void
    ) -> UIMenu {
        var sections: [UIMenuElement] = []
        if !owned {
            for format in formats {
                let audio = format == .audiobook
                sections.append(UIMenu(title: format.label, options: .displayInline, children: [
                    UIAction(
                        title: audio ? String(localized: "À écouter") : String(localized: "À lire"),
                        image: UIImage(systemName: "bookmark.fill")
                    ) { _ in Task { await onAdd(.toRead, format) } },
                    UIAction(
                        title: audio ? String(localized: "Déjà écouté") : String(localized: "Déjà lu"),
                        image: UIImage(systemName: "checkmark")
                    ) { _ in Task { await onAdd(.read, format) } },
                ]))
            }
            sections.append(UIMenu(options: .displayInline, children: [
                UIAction(
                    title: String(localized: "Liste d'envies"),
                    image: UIImage(systemName: wished ? "checkmark" : "bookmark"),
                    attributes: wished ? .disabled : []
                ) { _ in Task { await onWish() } },
            ]))
        }
        if !awaitable.isEmpty {
            sections.append(UIMenu(options: .displayInline, children: awaitable.map { format in
                UIAction(
                    title: format.awaitLabel,
                    image: UIImage(systemName: format == .audiobook ? "headphones" : "character.book.closed")
                ) { _ in onAwait(format) }
            }))
        }
        return UIMenu(children: sections)
    }
}
