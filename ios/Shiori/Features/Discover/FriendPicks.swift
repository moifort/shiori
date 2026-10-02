import SwiftUI

/// Who among the reader's friends loves one suggestion, the newest heart
/// first — the first is the friend whose copy a tap opens — and whether enough
/// of them do for the flame.
struct FriendLovers: Hashable, Codable, Sendable {
    struct Lover: Hashable, Codable, Sendable {
        let userId: String
        /// Nil for an account that never finished its onboarding.
        let firstName: String?

        var displayName: String { firstName ?? String(localized: "Un lecteur") }
    }

    let friends: [Lover]
    /// A third of the reader's friends hearted it, and two of them at least.
    let lovedByMany: Bool

    /// The friend whose copy stands for it.
    var first: Lover? { friends.first }

    /// "Marie", "Marie et Paul", "Marie +2": short enough for a tile's width.
    var caption: String {
        guard let first else { return "" }
        switch friends.count {
        case 1: return first.displayName
        case 2: return String(localized: "\(first.displayName) et \(friends[1].displayName)")
        default: return "\(first.displayName) +\(friends.count - 1)"
        }
    }
}

/// A book the friends hearted that the reader holds in no format.
struct LovedBook: Identifiable, Hashable, Codable, Sendable {
    let book: FriendBook
    let lovers: FriendLovers

    var id: String { book.id }
}

/// A saga the friends hearted, read or heard, that the reader holds no volume
/// of. Carries its first volume only, the cover its card draws.
struct LovedSaga: Identifiable, Codable, Sendable {
    let saga: FriendSaga
    let lovers: FriendLovers

    var id: String { saga.id }
}

/// An author of a book or a saga the friends hearted, whom the reader holds no
/// book of.
struct LovedAuthor: Identifiable, Hashable, Codable, Sendable {
    let key: String
    let name: String
    /// Nil until somebody opened their page and Wikipedia had a photograph.
    let portraitURL: URL?
    let lovers: FriendLovers

    var id: String { key }

    /// As the Authors shelf draws them: "Ursula K. Le Guin" is UG, not UK.
    var initials: String {
        let words = name.split(separator: " ")
        let ends = words.count > 1 ? [words.first, words.last] : [words.first]
        return ends.compactMap { $0?.first }.map(String.init).joined().uppercased()
    }
}

/// "Coups de cœur de vos amis": what Découvrir suggests from the friends'
/// hearts, whatever the format — a friend's recording is a story the reader
/// may take on paper.
struct FriendPicks: Codable, Sendable {
    var books: [LovedBook] = []
    var sagas: [LovedSaga] = []
    var authors: [LovedAuthor] = []
}

// MARK: - The shelves

/// The flame a suggestion many friends love carries in its corner.
struct LovedByManyBadge: View {
    var body: some View {
        Image(systemName: "flame.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(.orange, in: .circle)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .accessibilityLabel("Adoré par vos amis")
    }
}

/// A horizontal strip inside a list row, as the dashboard's shelves scroll:
/// edge to edge, with room above for the badges that overhang a corner.
private struct PicksStrip<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) { content }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .listRowInsets(EdgeInsets())
    }
}

/// The Books shelf's strip: the covers, the friend under each — no title, the
/// cover says it.
struct LovedBooksStrip: View {
    let books: [LovedBook]
    let onTapped: (LovedBook) -> Void

    var body: some View {
        PicksStrip {
            ForEach(books) { loved in
                Button { onTapped(loved) } label: {
                    CoverTile(book: loved.book.book, caption: loved.lovers.caption, showsTitle: false)
                        .overlay(alignment: .topLeading) {
                            if loved.lovers.lovedByMany {
                                LovedByManyBadge().offset(x: -6, y: -6)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("discover-friend-book")
            }
        }
    }
}

/// The Series shelf's strip: the first volume's cover, the saga's name and how
/// many volumes the friend holds, the friend under it.
struct LovedSagasStrip: View {
    let sagas: [LovedSaga]
    let onTapped: (LovedSaga) -> Void

    var body: some View {
        PicksStrip {
            ForEach(sagas) { loved in
                Button { onTapped(loved) } label: { card(loved) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-friend-saga")
            }
        }
    }

    private func card(_ loved: LovedSaga) -> some View {
        let width: CGFloat = 84
        return VStack(alignment: .leading, spacing: 4) {
            if let first = loved.saga.volumes.first {
                BookCover(book: first, width: width, formatBadgeSize: CoverTile.formatBadgeSize)
            }
            Text(loved.saga.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text("^[\(loved.saga.ownedCount) tome](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(loved.lovers.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if loved.lovers.lovedByMany {
                LovedByManyBadge().offset(x: -6, y: -6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(loved.saga.name), \(loved.lovers.caption)")
    }
}

/// The Authors shelf's strip: their faces, the name and the friend under each.
struct LovedAuthorsStrip: View {
    let authors: [LovedAuthor]
    let onTapped: (LovedAuthor) -> Void

    private let size: CGFloat = 64

    var body: some View {
        PicksStrip {
            ForEach(authors) { loved in
                Button { onTapped(loved) } label: { avatar(loved) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-friend-author")
            }
        }
    }

    private func avatar(_ loved: LovedAuthor) -> some View {
        VStack(spacing: 4) {
            AuthorAvatar(initials: loved.initials, portraitURL: loved.portraitURL, size: size)
                .overlay(alignment: .topTrailing) {
                    if loved.lovers.lovedByMany {
                        LovedByManyBadge().offset(x: 4, y: -4)
                    }
                }
            Text(loved.name)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(loved.lovers.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 84)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(loved.name), \(loved.lovers.caption)")
    }
}
