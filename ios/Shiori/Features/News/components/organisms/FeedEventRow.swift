import SwiftUI

/// A friend's move as a line of the library: the cover at full height on the
/// left, as in "Tous les livres", and over the title and author one small line
/// with their face, what they did and how long ago. Under the author, the
/// edition's tags (a foreign language, AUDIO) and their stars when they
/// finished it. No "…": sliding the row to the left opens its menu. The same
/// move by several friends is one row, their faces overlapping.
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

    /// The height of the text beside the cover, which the cover stretches to
    /// so its bottom sits level with the last line.
    @State private var textHeight: CGFloat?

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .top, spacing: 12) {
                BookCover(book: event.cover, showsFormatBadge: false, minHeight: textHeight)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .center, spacing: 7) {
                        faces
                        byline
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.bottom, 1)
                    Text(event.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if !event.authors.isEmpty {
                        Text(event.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    if hasMarks {
                        HStack(spacing: 6) {
                            CoverTags(language: event.language, isAudio: event.format == .audiobook, isFrosted: false)
                            if let stars {
                                Text(verbatim: stars)
                                    .font(.caption)
                            }
                        }
                        .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .swipeOpensMenu(
            .newsRow(
                format: event.format, owned: event.inLibrary, wished: wished, awaited: awaited,
                onAdd: onAdd, onWish: onWish, onAwait: onAwait
            )
        )
        .accessibilityIdentifier("news-event")
    }

    /// A tag or stars to draw under the author.
    private var hasMarks: Bool {
        stars != nil || !CoverTags(language: event.language, isAudio: event.format == .audiobook).isEmpty
    }

    /// "**Marc** a adoré · il y a 3 h": the names in full white, the rest grey.
    private var byline: Text {
        var line = sentence
        for run in line.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            line[run.range].foregroundColor = .primary
        }
        let when = event.at.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
        // Unbroken, so "il y a 5 h" never splits across two lines.
        line.append(AttributedString(" · " + when.replacingOccurrences(of: " ", with: "\u{00A0}")))
        return Text(line)
    }

    /// Their faces, small, the second tucked behind the first's edge.
    @ViewBuilder
    private var faces: some View {
        HStack(spacing: -7) {
            AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: 20)
            if let second = others.first {
                AccountAvatarView(avatar: second.avatar, firstName: second.friendName, size: 20)
                    .padding(1.5)
                    .background(Color(.systemBackground), in: .circle)
                    .padding(-1.5)
                    .zIndex(-1)
            }
        }
    }

    /// The stars of a book finished; "a adoré" says enough, "a commencé" has none.
    private var stars: String? {
        guard event.kind == .finished, let rating = event.rating, rating > 0 else { return nil }
        return UpcomingRelease.stars(rating)
    }

    private var sentence: AttributedString {
        guard let second = others.first else { return single }
        let first = event.friendName
        let other = second.friendName
        let rest = others.count - 1
        switch (event.kind, rest) {
        case (.loved, 0): return AttributedString(localized: "**\(first)** et **\(other)** ont adoré")
        case (.finished, 0): return AttributedString(localized: "**\(first)** et **\(other)** ont terminé")
        case (.started, 0): return AttributedString(localized: "**\(first)** et **\(other)** ont commencé")
        case (.loved, 1): return AttributedString(localized: "**\(first)**, **\(other)** et 1 autre ont adoré")
        case (.finished, 1): return AttributedString(localized: "**\(first)**, **\(other)** et 1 autre ont terminé")
        case (.started, 1): return AttributedString(localized: "**\(first)**, **\(other)** et 1 autre ont commencé")
        case (.loved, _): return AttributedString(localized: "**\(first)**, **\(other)** et \(rest) autres ont adoré")
        case (.finished, _): return AttributedString(localized: "**\(first)**, **\(other)** et \(rest) autres ont terminé")
        case (.started, _): return AttributedString(localized: "**\(first)**, **\(other)** et \(rest) autres ont commencé")
        }
    }

    private var single: AttributedString {
        switch event.kind {
        case .loved: AttributedString(localized: "**\(event.friendName)** a adoré")
        case .finished: AttributedString(localized: "**\(event.friendName)** a terminé")
        case .started: AttributedString(localized: "**\(event.friendName)** a commencé")
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
