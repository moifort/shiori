import SwiftUI

/// The top of a book's page, as the TV app opens a film: the cover large over its
/// own colours, a line in the status's colour above the title, the author and
/// who reads a recording, one line of facts, then the page's actions under the
/// cover on Liquid Glass. The ground runs up under the toolbar, whose glass
/// buttons float over it; the text is drawn in the dark appearance whatever the
/// device's, since it sits on a darkened image either way.
struct BookHero<Actions: View>: View {
    let book: Book
    /// Where the book stands, over the title: its status on the reader's own
    /// page, "Pas encore paru" on a volume to come.
    var state: BookState?
    /// The reader awaits an edition of it: binoculars beside the title.
    var isAwaited = false
    var coverWidth: CGFloat = 108
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                BookCover(book: book, width: coverWidth)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                    .accessibilityHidden(true)
                identity
            }
            actions
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, CoverBackdrop.fadeHeight + 4)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: book.coverURL)
                // Up under the bars, the toolbar's glass floating over it.
                .padding(.top, -400)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let state {
                Text(state.text)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(state.tint)
                    .brightness(0.15)
                    .lineLimit(2)
                    .accessibilityIdentifier("book-state")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(book.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                if isAwaited {
                    AwaitedMark()
                        .accessibilityIdentifier("book-awaited-mark")
                }
            }
            .foregroundStyle(.white)
            Text(book.authorLine)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
            if let narratorLine = book.narratorLine {
                Text("Lu par \(narratorLine)")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                    .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .copyable([
            CopyableValue(title: "Copier le titre", value: book.title),
            CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            CopyableValue(title: "Copier le lecteur", value: book.narratorLine ?? ""),
        ])
    }

    /// The facts a reader weighs at a glance, on one line: the genre, the
    /// volume, the year, the length, a foreign language.
    private var metaLine: String {
        var parts: [String] = []
        if let genre = book.genre { parts.append(genre.label) }
        if let volume = book.series?.volume { parts.append(String(localized: "Tome \(volume)")) }
        if let year = book.firstPublishedIn ?? book.editionYear { parts.append(String(year)) }
        if let duration = book.durationLabel {
            parts.append(duration)
        } else if let pages = book.pageCount {
            parts.append(String(localized: "\(pages) pages"))
        }
        if let language = book.language, language.isForeign { parts.append(language.label) }
        return parts.joined(separator: " · ")
    }
}

extension BookHero where Actions == EmptyView {
    init(book: Book, state: BookState? = nil, isAwaited: Bool = false, coverWidth: CGFloat = 108) {
        self.init(book: book, state: state, isAwaited: isAwaited, coverWidth: coverWidth) { EmptyView() }
    }
}

extension BookState {
    /// Where the reader's own copy stands, as the line over its title says it:
    /// in the status's colour, with the day that dates it.
    static func reading(of book: Book) -> BookState {
        let day: (Date) -> String = { $0.formatted(.dateTime.day().month(.abbreviated)) }
        switch book.status {
        case .toRead:
            if book.forthcoming { return .forthcoming }
            guard let added = book.addedAt else { return BookState(text: book.status.label, tint: book.status.tint) }
            return BookState(text: String(localized: "À lire · ajouté le \(day(added))"), tint: book.status.tint)
        case .reading:
            if let progress = book.listeningProgressLabel {
                return BookState(text: String(localized: "En cours · \(progress) écouté"), tint: book.status.tint)
            }
            guard let started = book.startedAt else { return BookState(text: book.status.label, tint: book.status.tint) }
            let days = started.daysAgo()
            return BookState(
                text: days == 0
                    ? String(localized: "En cours · commencé aujourd'hui")
                    : String(localized: "En cours · depuis \(days) j"),
                tint: book.status.tint
            )
        case .read:
            guard let finished = book.finishedAt else { return BookState(text: book.status.label, tint: book.status.tint) }
            return BookState(text: String(localized: "Lu · le \(day(finished))"), tint: book.status.tint)
        case .dropped:
            return BookState(text: book.status.label, tint: book.status.tint)
        }
    }
}

#Preview("Reading") {
    ScrollView {
        BookHero(book: .preview, state: .reading(of: .preview)) {
            HStack {
                Button("Marquer lu", systemImage: "checkmark") {}
                    .buttonStyle(.glassProminent)
                Button("Noter", systemImage: "star") {}
                    .buttonStyle(.glass)
            }
        }
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("No cover") {
    ScrollView {
        BookHero(book: .previewFromShelf, state: .reading(of: .previewFromShelf))
    }
}
