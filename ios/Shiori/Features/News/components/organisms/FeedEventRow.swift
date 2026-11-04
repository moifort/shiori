import SwiftUI

/// A friend's move as a notification: their face, what they did to the book in
/// one sentence, their stars beneath when they finished it, how long ago; a
/// small cover tagged in its corner and the "…" at the end. The same move by several friends is one row, the
/// second face over the first's corner.
struct FeedEventRow: View {
    let event: FeedEvent
    /// The other friends who made the same move, the latest first.
    var others: [FeedEvent] = []
    var wished = false
    var awaited = false
    let onOpen: () -> Void
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    let onWish: () async -> Void
    let onAwait: (ReleaseFormat) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpen) {
                HStack(alignment: .top, spacing: 12) {
                    faces
                    VStack(alignment: .leading, spacing: 2) {
                        (sentence + Text(verbatim: " ") + Text(event.title).fontWeight(.semibold))
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        if let stars {
                            Text(verbatim: stars)
                                .font(.caption)
                        }
                        Text(event.at.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated)))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    BookCover(book: event.cover, width: 34, showsFormatBadge: false)
                        .overlay(alignment: .topTrailing) {
                            CoverTags(language: event.language, isAudio: event.format == .audiobook)
                                .scaleEffect(0.7, anchor: .topTrailing)
                                .padding(2)
                        }
                        .padding(.top, 2)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            NewsRowMenu(
                format: event.format, owned: event.inLibrary, wished: wished, awaited: awaited,
                onAdd: onAdd, onWish: onWish, onAwait: onAwait
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .accessibilityIdentifier("news-event")
    }

    @ViewBuilder
    private var faces: some View {
        if let second = others.first {
            AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: 44)
                .overlay(alignment: .bottomTrailing) {
                    AccountAvatarView(avatar: second.avatar, firstName: second.friendName, size: 26)
                        .padding(2)
                        .background(Color(.systemBackground), in: .circle)
                        .offset(x: 6, y: 6)
                }
        } else {
            AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: 44)
        }
    }

    /// The stars of a book finished; "a adoré" says enough, "a commencé" has none.
    private var stars: String? {
        guard event.kind == .finished, let rating = event.rating, rating > 0 else { return nil }
        return UpcomingRelease.stars(rating)
    }

    private var sentence: Text {
        guard let second = others.first else { return single }
        let first = event.friendName
        let other = second.friendName
        let rest = others.count - 1
        switch (event.kind, rest) {
        case (.loved, 0): return Text("**\(first)** et **\(other)** ont adoré")
        case (.finished, 0): return Text("**\(first)** et **\(other)** ont terminé")
        case (.started, 0): return Text("**\(first)** et **\(other)** ont commencé")
        case (.loved, 1): return Text("**\(first)**, **\(other)** et 1 autre ont adoré")
        case (.finished, 1): return Text("**\(first)**, **\(other)** et 1 autre ont terminé")
        case (.started, 1): return Text("**\(first)**, **\(other)** et 1 autre ont commencé")
        case (.loved, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont adoré")
        case (.finished, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont terminé")
        case (.started, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont commencé")
        }
    }

    private var single: Text {
        switch event.kind {
        case .loved: Text("**\(event.friendName)** a adoré")
        case .finished: Text("**\(event.friendName)** a terminé")
        case .started: Text("**\(event.friendName)** a commencé")
        }
    }
}

#Preview("Feed event row") {
    VStack(spacing: 0) {
        ForEach(FeedEvent.previews) { event in
            FeedEventRow(event: event, onOpen: {}, onAdd: { _, _ in }, onWish: {}, onAwait: { _ in })
        }
        FeedEventRow(
            event: FeedEvent.previews[1], others: Array(FeedEvent.sameStartPreviews),
            onOpen: {}, onAdd: { _, _ in }, onWish: {}, onAwait: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
