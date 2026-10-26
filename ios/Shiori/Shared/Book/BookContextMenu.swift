import SwiftUI

/// What a long press on a cover can ask for: the next step of the book's
/// status, a heart, stars, its series or its author, and taking it out.
enum BookQuickAction: Hashable {
    case setStatus(ReadingStatus)
    case toggleFavorite
    case rate
    case openSeries(String)
    /// The author's key and name.
    case openAuthor(key: String, name: String)
    case remove
}

extension View {
    /// The long press on a cover, as the TV app lifts a poster: the cover over
    /// a blurred ground, and a glass menu suited to the book's status — what
    /// to do next with it first, then where it leads, and its removal in red,
    /// icon included. Nil `onAction` leaves the cover without one.
    @ViewBuilder
    func bookContextMenu(_ book: Book, onAction: ((BookQuickAction) -> Void)?) -> some View {
        if let onAction {
            contextMenu {
                BookContextMenuItems(book: book, onAction: onAction)
            } preview: {
                BookContextPreview(book: book)
            }
        } else {
            self
        }
    }
}

/// The menu's items, by status.
private struct BookContextMenuItems: View {
    let book: Book
    let onAction: (BookQuickAction) -> Void

    var body: some View {
        Section {
            switch book.status {
            case .toRead:
                Button(book.format == .audiobook ? "Commencer l'écoute" : "Commencer la lecture", systemImage: "book") {
                    onAction(.setStatus(.reading))
                }
            case .reading:
                Button("J'ai fini ce livre", systemImage: "checkmark") { onAction(.setStatus(.read)) }
                Button("Abandonner", systemImage: "hand.thumbsdown") { onAction(.setStatus(.dropped)) }
            case .read:
                Button("Relire", systemImage: "arrow.counterclockwise") { onAction(.setStatus(.reading)) }
            case .dropped:
                Button("Reprendre la lecture", systemImage: "book") { onAction(.setStatus(.reading)) }
            }
            Button(
                book.favorite ? "Retirer des coups de cœur" : "Coup de cœur",
                systemImage: book.favorite ? "heart.slash" : "heart"
            ) { onAction(.toggleFavorite) }
            Button("Noter", systemImage: "star") { onAction(.rate) }
        }
        Section {
            if let series = book.series {
                Button("Voir la série", systemImage: "square.stack") { onAction(.openSeries(series.id)) }
            }
            if let author = book.authors.first, let key = book.authorKeys?.first {
                Button("Voir l'auteur", systemImage: "person") { onAction(.openAuthor(key: key, name: author)) }
            }
            ShareLink(item: "\(book.title) — \(book.authorLine)") {
                Label("Partager", systemImage: "square.and.arrow.up")
            }
        }
        Section {
            Button(role: .destructive) {
                onAction(.remove)
            } label: {
                Label("Supprimer", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        }
    }
}

/// The cover lifted over the blurred ground, its title and its state beside it.
private struct BookContextPreview: View {
    let book: Book

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            BookCover(book: book, width: 130, showsFormatBadge: false, cornerRadius: 6)
                .overlay(alignment: .topLeading) {
                    if book.status == .reading { BookmarkRibbon().padding(.leading, 12) }
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.title3.weight(.bold))
                    .lineLimit(3)
                Text(book.authorLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let state {
                    Text(state)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .frame(width: 150, alignment: .leading)
        }
        .padding(16)
        .environment(\.colorScheme, .dark)
    }

    private var state: String? {
        guard book.status == .reading, let since = book.shelvedAt else { return nil }
        if PosterLabel.Span(from: since, to: .now) == .today { return String(localized: "commencé aujourd'hui") }
        return String(localized: "en cours \(PosterLabel.open(since, now: .now))")
    }
}

#Preview {
    PosterCover(book: .preview, caption: "depuis 6j")
        .bookContextMenu(.preview) { _ in }
        .padding()
}
