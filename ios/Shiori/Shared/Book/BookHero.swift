import SwiftUI

/// The top of a book's page, as the TV app opens a film: the cover large over
/// its own colours, which melt into the page over the lower half of the hero,
/// and beside it the text as the home's "En cours" card sets it — the saga
/// over the title, as the TV app names the show over the episode, the author
/// and who reads a recording, then one line of where the book stands in its
/// status's colour and the facts weighed at a glance, the format in an
/// outlined tag — then the page's actions on Liquid Glass. The ground runs up
/// under the toolbar, whose glass buttons float over it; the text is drawn in
/// the dark appearance whatever the device's, since it sits on a darkened
/// image either way.
struct BookHero<Actions: View>: View {
    let book: Book
    /// Where the book stands, on the detail line: its status on the reader's
    /// own page, "Pas encore paru" on a volume to come.
    var state: BookState?
    /// The reader awaits an edition of it: binoculars beside the title.
    var isAwaited = false
    var coverWidth: CGFloat = 108
    @ViewBuilder var actions: Actions

    /// How tall the fade into the page is: long and eased, under the actions,
    /// so the colours melt into the page rather than stop at a line under
    /// the buttons.
    private static var fadeHeight: CGFloat { 160 }

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
        .padding(.bottom, 28)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: book.coverURL, fadeHeight: Self.fadeHeight)
                // Up under the bars, the toolbar's glass floating over it.
                .padding(.top, -400)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let overline {
                Text(overline)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
                    .accessibilityIdentifier("book-saga-line")
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
            detailLine
                .padding(.top, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .copyable([
            CopyableValue(title: "Copier le titre", value: book.title),
            CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            CopyableValue(title: "Copier le lecteur", value: book.narratorLine ?? ""),
        ])
    }

    /// Over the title: the saga and the volume's place in it, as the TV app
    /// names the show over the episode. Nothing for a book on its own.
    private var overline: String? {
        guard let series = book.series else { return nil }
        guard let volume = series.volume else { return series.name }
        return "\(series.name) · \(String(localized: "Tome \(volume)"))"
    }

    /// Where the book stands, in its colour, then the facts a reader weighs
    /// at a glance — the genre, the year, the length, a foreign language —
    /// with the format in an outlined tag, as the TV app tags a film "4K".
    @ViewBuilder private var detailLine: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let state {
                Text(state.text)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(state.tint)
                    .brightness(0.15)
                    .lineLimit(2)
                    .accessibilityIdentifier("book-state")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let meta = metaLine
                if !meta.isEmpty {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                }
                OutlinedTag(text: formatTag)
            }
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let genre = book.genre { parts.append(genre.label) }
        if let year = book.firstPublishedIn ?? book.editionYear { parts.append(String(year)) }
        if let duration = book.durationLabel {
            parts.append(duration)
        } else if let pages = book.pageCount {
            parts.append(String(localized: "\(pages) pages"))
        }
        if let language = book.language, language.isForeign { parts.append(language.label) }
        return parts.joined(separator: " · ")
    }

    /// "Audio" for a recording, as the home's card tags it, else the format.
    private var formatTag: String {
        book.format == .audiobook ? String(localized: "Audio") : book.format.label
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
                    : String(localized: "En cours · depuis \(days)j"),
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
