import SwiftUI

/// What a book is, drawn the same on every page that shows one — the reader's
/// own copy, a friend's, a volume announced, an edition awaited, a scan being
/// checked: the cover and the title, the author and the volume, who reads a
/// recording, the way out to a store, then the facts of its publication under
/// a rule that runs the whole width. Only what is known is drawn.
///
/// A page that lets the reader correct a fact hands over the action for it:
/// the saga and the genre open their prompt from a row with a chevron, and the
/// publisher, the year, the pages and the ISBN are typed straight into their
/// row. Without one the row only states the fact. A page may say where the
/// book stands for the reader under the author, show when it comes out in the
/// corner, and add rows of its own under the facts.
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
        /// Names the saga instead of opening it, where the book is not filed yet.
        var editSeries: (() -> Void)?
        var editIdentity: (() -> Void)?
        var editGenre: (() -> Void)?
        /// Makes the publisher, the year, the pages and the ISBN typed in place.
        var correct: ((BookCorrection) -> Void)?
    }

    let book: Book
    var state: BookState?
    /// A volume still to come: the day it is out, as a calendar leaf in the
    /// corner, as the saga screen draws its next volume.
    var releaseDate: String?
    /// The reader awaits an edition of it: binoculars beside the title.
    var isAwaited = false
    /// Nil opens the book's own Audible page, when it has one.
    var storeLink: StoreLink?
    var actions = Actions()
    /// Draws a row for every fact, known or not, so a page checking a scan
    /// can fill in what the cover did not say.
    var showsEmptyFacts = false
    var footer: LocalizedStringKey?
    @ViewBuilder var extra: Extra

    private static var coverWidth: CGFloat { 64 }
    /// The cover at its standard proportions, as `BookCover` draws it.
    private static var coverHeight: CGFloat { coverWidth * 1.5 }

    @State private var contentEdge: CGFloat = 0
    @State private var cardEdge: CGFloat = 0

    /// How far the row's content sits inside its card.
    private var rowMargin: CGFloat {
        let measured = contentEdge - cardEdge
        return measured > 0 ? measured : 16
    }

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
        .toolbar {
            // The number pad has no return key: this is how a typed fact is
            // put down.
            if actions.correct != nil {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
                        )
                    }
                }
            }
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
            BookCover(book: book, width: Self.coverWidth)
            // Everything beside the cover: the text with, while the book is
            // still to come, its day in the corner.
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    textColumn
                    if let releaseDate, ReleaseDateText.isUpcoming(releaseDate) {
                        ReleaseDateBadge(date: releaseDate)
                            .accessibilityIdentifier("book-release-date")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        // A quiet tag in the corner rather than a row: a way out of Shiori,
        // not a fact about the book. On the card's trailing edge, its foot
        // level with the cover's however long the title runs.
        .overlay(alignment: .topTrailing) {
            if let link = shownStoreLink {
                Link(destination: link.url) {
                    Pill(text: link.name, tint: link.tint, trailingSystemImage: "arrow.up.right")
                }
                .buttonStyle(.borderless)
                .frame(height: Self.coverHeight, alignment: .bottom)
                .accessibilityLabel(Text("Ouvrir dans \(link.name)"))
                .accessibilityIdentifier("book-store-link")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 2)
        // The rule under the cover runs from one edge of the card to the
        // other: the list would start it under the title and stop it at the
        // margin. The guides are the row's own, so the rule is pushed out by
        // the margin measured between the row and its card — 16 or 20 points
        // with the width of the phone.
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { contentEdge = $0 }
        .listRowBackground(
            Color(.secondarySystemGroupedBackground)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minX } action: { cardEdge = $0 }
        )
        .alignmentGuide(.listRowSeparatorLeading) { _ in -rowMargin }
        .alignmentGuide(.listRowSeparatorTrailing) { dimensions in dimensions.width + rowMargin }
        .copyable([
            CopyableValue(title: "Copier le titre", value: book.title),
            CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            CopyableValue(title: "Copier le lecteur", value: book.narratorLine ?? ""),
        ])
    }

    private var textColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The pills share the first line only: beside a whole column they
            // squeezed the title, the author and the reader into half the
            // width the row has. On the title's baseline, so the taller pills
            // do not push the author down.
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(book.title).font(.headline)
                Spacer(minLength: 0)
                pills
            }
            // The volume after the author, on the same line: a fact about the
            // book rather than a heading over its title.
            HStack(spacing: 4) {
                Text(book.authorLine)
                if let series = book.series {
                    Text(verbatim: "· \(series.label)").fixedSize()
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            // Who reads a recording is as much a reason to pick it as who wrote
            // it, so it sits with the author. Only a recording has one.
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        seriesRow
        genreRow
        ForEach(BookFact.allCases, id: \.self) { fact in
            factRow(fact)
        }
    }

    @ViewBuilder
    private var seriesRow: some View {
        if let editSeries = actions.editSeries {
            Button(action: editSeries) {
                Label {
                    LabeledContent("Série") {
                        HStack(spacing: 4) {
                            Text(book.series?.name ?? String(localized: "Aucune"))
                                .multilineTextAlignment(.trailing)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.tint)
                    }
                } icon: {
                    Image(systemName: "square.stack").foregroundStyle(.secondary)
                }
            }
            .tint(.primary)
            .accessibilityIdentifier("book-series")
        } else if let series = book.series {
            if let openSeries = actions.openSeries {
                SeriesLinkRow(name: series.name, action: openSeries)
                    .accessibilityIdentifier("book-series")
            } else {
                LabeledInfoRow(title: "Série", value: series.name, icon: "square.stack")
                    .accessibilityIdentifier("book-series")
            }
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

    /// A fact as the other rows draw theirs, typed in place where the page
    /// corrects it; a long press copies it either way.
    @ViewBuilder
    private func factRow(_ fact: BookFact) -> some View {
        let value = fact.value(of: book)
        if let correct = actions.correct, value != nil || showsEmptyFacts {
            InlineFactField(fact: fact, book: book, onCorrect: correct)
        } else if let value {
            Label {
                LabeledContent(fact.title) {
                    Text(value).font(fact.font)
                }
            } icon: {
                Image(systemName: fact.icon).foregroundStyle(.secondary)
            }
            .copyable(value)
            .accessibilityIdentifier("book-\(fact.rawValue)")
        }
    }
}

extension BookHeaderSection where Extra == EmptyView {
    init(
        book: Book,
        state: BookState? = nil,
        releaseDate: String? = nil,
        isAwaited: Bool = false,
        storeLink: StoreLink? = nil,
        actions: Actions = Actions(),
        showsEmptyFacts: Bool = false,
        footer: LocalizedStringKey? = nil
    ) {
        self.init(
            book: book,
            state: state,
            releaseDate: releaseDate,
            isAwaited: isAwaited,
            storeLink: storeLink,
            actions: actions,
            showsEmptyFacts: showsEmptyFacts,
            footer: footer
        ) { EmptyView() }
    }
}
