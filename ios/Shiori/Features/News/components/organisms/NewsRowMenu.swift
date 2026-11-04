import SwiftUI

/// The "…" at the end of an Actualités row: the friend's book hero's own menu,
/// to take the book, wish for it or await its recording without leaving the
/// tab. A recording is never offered heard again.
struct NewsRowMenu: View {
    let format: BookFormat
    /// The reader holds the story already, or just took it.
    let owned: Bool
    /// On the wishlist already, from this menu.
    let wished: Bool
    /// Its recording awaited already, from this menu.
    let awaited: Bool
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    let onWish: () async -> Void
    let onAwait: (ReleaseFormat) -> Void

    private var awaitable: [ReleaseFormat] {
        format == .audiobook || awaited ? [] : [.audiobook]
    }

    var body: some View {
        Menu {
            BookAddMenuItems(
                formats: format.takenAs,
                owned: owned,
                awaitable: awaitable,
                onAdd: onAdd,
                wished: wished,
                onAwait: onAwait,
                onWish: onWish
            )
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 44)
                .contentShape(.rect)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .opacity(owned && awaitable.isEmpty ? 0.35 : 1)
        .disabled(owned && awaitable.isEmpty)
        .accessibilityLabel("Plus d'actions")
        .accessibilityIdentifier("news-row-menu")
    }
}

#Preview {
    HStack(spacing: 30) {
        NewsRowMenu(
            format: .book, owned: false, wished: false, awaited: false,
            onAdd: { _, _ in }, onWish: {}, onAwait: { _ in }
        )
        NewsRowMenu(
            format: .audiobook, owned: true, wished: false, awaited: false,
            onAdd: { _, _ in }, onWish: {}, onAwait: { _ in }
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
