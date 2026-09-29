import SwiftUI

/// What a book is, drawn the same on every page that shows one — the reader's
/// own copy, a friend's, a volume announced, an edition awaited, a scan being
/// checked: the cover and the title, the author and the volume, who reads a
/// recording, the way out to a store, then the facts of its publication under
/// a rule that runs the whole width. Only what is known is drawn.
///
/// A page that lets the reader correct a fact hands over the action for it,
/// and that row draws a chevron or opens on a tap; without one the row only
/// states the fact. A page may pin where the book stands for the reader on the
/// cover, and add rows of its own under the facts.
struct BookHeaderSection<Extra: View>: View {
    /// A store the book can be opened in: its name on the tag, and where. A
    /// store with a colour of its own — Audible — draws its tag in it.
    struct StoreLink {
        let name: String
        let url: URL
        var tint: Color? = nil
    }

    /// What the page lets the reader do from the header. Each nil action
    /// leaves its row read-only.
    struct Actions {
        var openSeries: (() -> Void)?
        var editIdentity: (() -> Void)?
        var editGenre: (() -> Void)?
        var editField: ((BookField) -> Void)?
    }

    let book: Book
    var state: BookState?
    /// The reader awaits an edition of it: binoculars beside the title.
    var isAwaited = false
    /// Nil opens the book's own Audible page, when it has one.
    var storeLink: StoreLink?
    var actions = Actions()
    var footer: LocalizedStringKey?
    @ViewBuilder var extra: Extra

    private var shownStoreLink: StoreLink? {
        storeLink ?? book.audibleURL.map { StoreLink(name: "Audible", url: $0, tint: .audible) }
    }

    var body: some View {
        Section {
            identity
            facts
            extra
        } footer: {
            if let footer { Text(footer) }
        }
    }

    // MARK: - Identity

    @ViewBuilder
    private var identity: some View {
        if let editIdentity = actions.editIdentity {
            Button(action: editIdentity) { identityRow }
                .tint(.primary)
                .accessibilityIdentifier("book-identity")
        } else {
            identityRow
        }
    }

    private var identityRow: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: book, width: 64)
                // On the cover's foot, the headphones keeping its top corner.
                .overlay(alignment: .bottomTrailing) {
                    if let state {
                        BookStateBadge(state: state)
                            .offset(x: 6, y: 6)
                            .accessibilityIdentifier("book-state-badge")
                    }
                }
            VStack(alignment: .leading, spacing: 2) {
                // The pills share the first line only: beside a whole column
                // they squeezed the title, the author and the reader into half
                // the width the row has. On the title's baseline, so the taller
                // pills do not push the author down.
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(book.title).font(.headline)
                    Spacer(minLength: 0)
                    pills
                }
                // The volume after the author, on the same line: a fact about
                // the book rather than a heading over its title.
                HStack(spacing: 4) {
                    Text(book.authorLine)
                    if let series = book.series {
                        Text(verbatim: "· \(series.label)").fixedSize()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                // Who reads a recording is as much a reason to pick it as who
                // wrote it, so it sits with the author. Only a recording has one.
                if let narratorLine = book.narratorLine {
                    Text("Lu par \(narratorLine)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 1)
                }
                if let state {
                    Text(state.text)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(state.tint)
                        .padding(.top, 2)
                        .accessibilityIdentifier("book-state")
                }
                // A quiet tag in the corner rather than a row: a way out of
                // Shiori, not a fact about the book. Pushed down to the foot of
                // the cover: the row is as tall as the cover or the text,
                // whichever is taller.
                if let link = shownStoreLink {
                    Spacer(minLength: 0)
                    Link(destination: link.url) {
                        Pill(text: link.name, tint: link.tint, trailingSystemImage: "arrow.up.right")
                    }
                    .buttonStyle(.borderless)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 4)
                    .accessibilityLabel(Text("Ouvrir dans \(link.name)"))
                    .accessibilityIdentifier("book-store-link")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        // The rule under the cover runs the whole width: the list would start
        // it under the title, leaving the cover hanging over nothing.
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
        .copyable([
            CopyableValue(title: "Copier le titre", value: book.title),
            CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            CopyableValue(title: "Copier le lecteur", value: book.narratorLine ?? ""),
        ])
    }

    /// The facts a listener or a reader weighs at a glance, in the corner: how
    /// far the recording got, how long it runs, a foreign language, a drawn
    /// story's format. That it is a recording is said by the pill on the cover.
    private var pills: some View {
        HStack(spacing: 6) {
            if isAwaited {
                AwaitedMark()
                    .accessibilityIdentifier("book-awaited-mark")
            }
            // The picker of the reader's own page has no segment for it.
            if book.status == .dropped {
                ReadingStatusBadge(status: .dropped)
                    .scaleEffect(1.2)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(book.status.label))
                    .accessibilityIdentifier("book-dropped")
            }
            if let language = book.language, language.isForeign {
                LanguageTag(language: language)
            }
            // How far the Audible player got, while the recording is under way
            // only, in the colour of "En cours", which it measures.
            if book.status == .reading, let progress = book.listeningProgressLabel {
                Pill(text: progress, tint: ReadingStatus.reading.tint)
                    .accessibilityLabel(Text("Écouté à \(progress)"))
                    .accessibilityIdentifier("book-listening-progress")
            }
            if let durationLabel = book.durationLabel {
                Pill(text: durationLabel, systemImage: "clock")
                    .accessibilityIdentifier("book-duration")
            }
            if book.format != .book && book.format != .audiobook {
                Image(systemName: book.format.symbol)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(book.format.label))
                    .accessibilityIdentifier("book-format")
            }
        }
    }

    // MARK: - Facts

    @ViewBuilder
    private var facts: some View {
        if let series = book.series {
            if let openSeries = actions.openSeries {
                SeriesLinkRow(name: series.name, action: openSeries)
                    .accessibilityIdentifier("book-series")
            } else {
                LabeledInfoRow(title: "Série", value: series.name, icon: "square.stack")
                    .accessibilityIdentifier("book-series")
            }
        }
        genreRow
        if let publisher = book.publisher {
            LabeledInfoRow(title: "Éditeur", value: publisher, icon: "building.2")
        }
        if let year = book.firstPublishedIn {
            factRow(.firstPublishedIn, value: String(year), icon: "calendar")
        }
        if let pages = book.pageCount {
            factRow(.pageCount, value: String(pages), icon: "doc.plaintext")
        }
        if let isbn = book.isbn13 {
            factRow(.isbn13, value: isbn, icon: "barcode", font: .callout.monospaced())
        }
    }

    /// The genre and its subgenres on one row. Where it can be corrected, a
    /// book with neither still gets the row, saying so: it is the way to give
    /// it one.
    @ViewBuilder
    private var genreRow: some View {
        if let editGenre = actions.editGenre {
            Button(action: editGenre) {
                genreLabel(chevron: true)
            }
            .tint(.primary)
            .accessibilityIdentifier("book-genre")
        } else if book.genre != nil || !book.subgenres.isEmpty {
            genreLabel(chevron: false)
                .accessibilityIdentifier("book-genre")
        }
    }

    private func genreLabel(chevron: Bool) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent("Genre") {
                    HStack(spacing: 4) {
                        if let genre = book.genre {
                            genre.image.imageScale(.small)
                        }
                        Text(book.genre?.label ?? String(localized: "Non renseigné"))
                            .multilineTextAlignment(.trailing)
                        if chevron {
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                    }
                    .foregroundStyle(chevron ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                }
                if !book.subgenres.isEmpty {
                    TagList(tags: book.subgenres, systemImage: "tag")
                }
            }
        } icon: {
            // Neutral here: the genre's own glyph sits beside its name.
            Image(systemName: "books.vertical").foregroundStyle(.secondary)
        }
    }

    /// A fact as the other rows draw theirs. Where the page corrects it, a tap
    /// opens the prompt for that one value; a long press copies it either way.
    @ViewBuilder
    private func factRow(_ field: BookField, value: String, icon: String, font: Font? = nil) -> some View {
        let label = Label {
            LabeledContent(field.title) {
                Text(value).font(font)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
        if let editField = actions.editField {
            Button { editField(field) } label: { label }
                .tint(.primary)
                .copyable(value)
                .accessibilityIdentifier("book-\(field.rawValue)")
        } else {
            label
                .copyable(value)
                .accessibilityIdentifier("book-\(field.rawValue)")
        }
    }
}

extension BookHeaderSection where Extra == EmptyView {
    init(
        book: Book,
        state: BookState? = nil,
        isAwaited: Bool = false,
        storeLink: StoreLink? = nil,
        actions: Actions = Actions(),
        footer: LocalizedStringKey? = nil
    ) {
        self.init(
            book: book,
            state: state,
            isAwaited: isAwaited,
            storeLink: storeLink,
            actions: actions,
            footer: footer
        ) { EmptyView() }
    }
}
