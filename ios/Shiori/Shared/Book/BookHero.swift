import SwiftUI

/// The top of a book's page, as the TV app opens a film: the cover large over
/// its own colours, which melt into the page well past the hero, and beside it
/// the text as the home's "En cours" card sets it — the saga over the title,
/// as the TV app names the show over the episode, the author and who reads a
/// recording, then where the reader stands and how long the book runs, the
/// format in an outlined tag, and how much of a recording is left on a small
/// bar — then the page's actions on Liquid Glass. The genre and the year are
/// left to the facts under it. The ground runs up under the toolbar, whose
/// glass buttons float over it; the text is drawn in the dark appearance
/// whatever the device's, since it sits on a darkened image either way.
struct BookHero<Actions: View>: View {
    let book: Book
    /// Where the reader stands, first on the detail line: "depuis 3j" on the
    /// reader's own page, "Pas encore paru" on a volume to come.
    var state: BookState?
    /// The reader awaits an edition of it: binoculars beside the title.
    var isAwaited = false
    /// How long the book runs on the detail line — pages, or a recording's
    /// hours. Off where the facts under the hero say it and nothing else does.
    var showsLength = true
    /// Opens an author's page from the author line, a chevron after it. Nil
    /// draws the line alone, as where the book came without its authors' keys.
    var onOpenAuthor: ((AuthorDestination) -> Void)? = nil
    /// Opens a narrator's page from the "Lu par" line, as the author line
    /// opens an author's. Nil draws the line alone.
    var onOpenNarrator: ((NarratorDestination) -> Void)? = nil
    var coverWidth: CGFloat = 108
    /// The day a book to come is out, as a calendar leaf on glass in the
    /// corner level with the cover's top, as the saga's release card pins it.
    var releaseDate: String? = nil
    /// How long is left until then — "2 mois", "20 jours" — tagged on the
    /// detail line after the format, as the format is.
    var countdown: String? = nil
    @ViewBuilder var actions: Actions

    /// The text's height and the cover's, to tell whether the text climbs
    /// past the calendar leaf.
    @State private var identityHeight: CGFloat = 0
    @State private var coverHeight: CGFloat = 0

    /// The calendar leaf's side and the gap the text keeps from it.
    private static var leafRoom: CGFloat { 48 + 10 }

    /// How tall the fade into the page is: long and eased, so the colours
    /// melt into the page rather than stop at a line under the buttons.
    private static var fadeHeight: CGFloat { 320 }
    /// How far the backdrop runs on under the hero, behind the first block:
    /// the fade's lower half, so the buttons still sit on the colours.
    private static var fadeOverhang: CGFloat { 170 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom, spacing: 16) {
                // No format badge: the outlined tag on the detail line says it.
                BookCover(book: book, width: coverWidth, showsFormatBadge: false)
                    .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                    .accessibilityHidden(true)
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { coverHeight = $0 }
                identity
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { identityHeight = $0 }
            }
            // In the corner over the text, level with the cover's top: what
            // the reader decided of the book, apart from what it is, and the
            // day a book to come is out.
            .overlay(alignment: .topTrailing) {
                HStack(alignment: .top, spacing: 8) {
                    marks
                    if let releaseDate {
                        ReleaseDateBadge(date: releaseDate, onGlass: true)
                    }
                }
                .font(.body)
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
                // Up under the bars, the toolbar's glass floating over it,
                // and on under the first block, which draws over it.
                .padding(.top, -400)
                .padding(.bottom, -Self.fadeOverhang)
        }
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let series = book.series {
                // The saga's name gives way before the volume's number does.
                HStack(spacing: 4) {
                    Text(series.name)
                        .layoutPriority(-1)
                    if let volume = series.volume {
                        Text(verbatim: "· \(String(localized: "Tome \(volume)"))")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .padding(.trailing, besideLeaf)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("book-saga-line")
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(book.title)
                    .font(.title2.weight(.bold))
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.trailing, besideLeaf)
            authorLine
            narratorLine
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

    /// Room kept for the calendar leaf beside the saga line and the title,
    /// once the text runs taller than the cover leaves under the leaf: it
    /// climbs beside it rather than under it.
    private var besideLeaf: CGFloat {
        guard releaseDate != nil, identityHeight > coverHeight - Self.leafRoom else { return 0 }
        return Self.leafRoom
    }

    /// The authors, and the way to their page: a chevron after the line, as
    /// the saga's row heads its name. One author opens at once; several
    /// offer the choice, each by name.
    @ViewBuilder private var authorLine: some View {
        let line = Text(book.authorLine)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(2)
        let authors = book.authorDestinations
        if let onOpenAuthor, let first = authors.first {
            let label = HStack(alignment: .firstTextBaseline, spacing: 4) {
                line
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
            if authors.count == 1 {
                Button { onOpenAuthor(first) } label: { label }
                    .buttonStyle(.plain)
                    .accessibilityHint(Text("Ouvre la fiche de l'auteur"))
                    .accessibilityIdentifier("book-author-link")
            } else {
                Menu {
                    ForEach(authors) { author in
                        Button(author.name, systemImage: "person") { onOpenAuthor(author) }
                    }
                } label: { label }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("book-author-link")
            }
        } else {
            line
        }
    }

    /// Who reads the recording, and the way to their page, as the author line
    /// leads to the author's: one narrator opens at once, several offer the
    /// choice, each by name.
    @ViewBuilder private var narratorLine: some View {
        if let narratorLine = book.narratorLine {
            let line = Text("Lu par \(narratorLine)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            let narrators = book.narratorDestinations
            if let onOpenNarrator, let first = narrators.first {
                let label = HStack(alignment: .firstTextBaseline, spacing: 4) {
                    line
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .accessibilityHidden(true)
                }
                .contentShape(.rect)
                if narrators.count == 1 {
                    Button { onOpenNarrator(first) } label: { label }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Ouvre la fiche du narrateur"))
                        .accessibilityIdentifier("book-narrator-link")
                } else {
                    Menu {
                        ForEach(narrators) { narrator in
                            Button(narrator.name, systemImage: "waveform") { onOpenNarrator(narrator) }
                        }
                    } label: { label }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("book-narrator-link")
                }
            } else {
                line
            }
        }
    }

    /// What the reader decided of the book that its page does not otherwise
    /// say: kept out of the shared libraries, an edition awaited. Given up is
    /// the first button's to say.
    @ViewBuilder private var marks: some View {
        if book.hidden {
            Image(systemName: "eye.slash")
                .foregroundStyle(.white.opacity(0.7))
                .fixedSize()
                .accessibilityLabel(Text("Non partagé"))
                .accessibilityIdentifier("book-hidden-mark")
        }
        if isAwaited {
            AwaitedMark()
                .accessibilityIdentifier("book-awaited-mark")
        }
    }

    /// Where the reader stands and how long the book runs, as the home's card
    /// says it — "depuis 3j · 16h09" — with the format in an outlined tag, as
    /// the TV app tags a film "4K", then a recording's time left on its bar.
    @ViewBuilder private var detailLine: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                let line = details
                if !line.isEmpty {
                    Text(line)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)
                        .accessibilityIdentifier("book-state")
                }
                // Only a foreign edition and a recording are tagged: paper in
                // the phone's language is what a book is taken to be. Clear
                // over the hero's colours: no glass behind the words.
                CoverTags(book: book, isFrosted: false)
                if let countdown {
                    OutlinedTag(text: countdown, isFrosted: false)
                        .accessibilityLabel(Text("Dans \(countdown)"))
                        .accessibilityIdentifier("book-countdown")
                }
            }
            // Only while the book is under way: a finished one has nothing left.
            if book.status == .reading, let progress = book.listeningProgress {
                ListeningProgressLine(progress: progress, durationMinutes: book.durationMinutes)
            }
        }
    }

    private var details: String {
        var parts: [String] = []
        if let state { parts.append(state.text) }
        if showsLength {
            if let duration = book.durationLabel {
                parts.append(duration)
            } else if let pages = book.pageCount {
                parts.append(String(localized: "\(pages) pages"))
            }
        }
        return parts.joined(separator: " · ")
    }

}

extension Book {
    /// Each author with the key of their page, for the hero to open it. Empty
    /// when the keys did not come with the book, or do not match its authors.
    var authorDestinations: [AuthorDestination] {
        guard let authorKeys, authorKeys.count == authors.count else { return [] }
        return zip(authorKeys, authors).map { AuthorDestination(key: $0, name: $1) }
    }

    /// Each narrator with the key of their page, for the hero to open it.
    /// Empty when the keys did not come with the book, or do not match.
    var narratorDestinations: [NarratorDestination] {
        guard let narratorKeys, narratorKeys.count == narrators.count else { return [] }
        return zip(narratorKeys, narrators).map { NarratorDestination(key: $0, name: $1) }
    }
}

extension BookHero where Actions == EmptyView {
    init(book: Book, state: BookState? = nil, isAwaited: Bool = false, coverWidth: CGFloat = 108) {
        self.init(book: book, state: state, isAwaited: isAwaited, coverWidth: coverWidth) { EmptyView() }
    }
}

extension BookState {
    /// Where the reader's own copy stands, as the home's card says it, the
    /// units set against their figures: "à lire depuis 6j", "depuis 3j",
    /// "lu le 3 oct.". The colour is the status's, for whoever draws it.
    static func reading(of book: Book) -> BookState {
        let day: (Date) -> String = { $0.formatted(.dateTime.day().month(.abbreviated)) }
        let tint = book.status.tint
        switch book.status {
        case .toRead:
            if book.forthcoming { return .forthcoming }
            guard let added = book.addedAt else { return BookState(text: book.status.label.lowercased(), tint: tint) }
            let days = added.daysAgo()
            return BookState(
                text: days == 0 ? String(localized: "ajouté aujourd'hui") : String(localized: "à lire depuis \(days)j"),
                tint: tint
            )
        case .reading:
            guard let started = book.startedAt else { return BookState(text: book.status.label.lowercased(), tint: tint) }
            let days = started.daysAgo()
            return BookState(
                text: days == 0 ? String(localized: "commencé aujourd'hui") : String(localized: "depuis \(days)j"),
                tint: tint
            )
        case .read:
            guard let finished = book.finishedAt else { return BookState(text: book.status.label.lowercased(), tint: tint) }
            return BookState(text: String(localized: "lu le \(day(finished))"), tint: tint)
        case .dropped:
            return BookState(text: book.status.label.lowercased(), tint: tint)
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
