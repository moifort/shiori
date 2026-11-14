import SwiftUI

/// What the model proposed, before anything is saved, drawn as the book's page
/// draws a book: the hero over the cover's colours, then the summary, the
/// saga and the facts as tiles. Every fact is a guess — the safety net against
/// a misread cover — so every one can be corrected: the publisher, the year,
/// the pages and the ISBN from their tile, every tile shown even when the
/// cover said nothing; the title and author from the facts' header, the saga
/// and the genre from their sheets; the edition's language from its tile,
/// presumed the app's own. Nothing leaves the phone until the reader adds it.
///
/// A saga renamed here is not the one the scan keyed: it is handed over by
/// name, and the server files the book as the edit form files one — into the
/// saga the reader holds by that name, or a new one keyed on its author.
///
/// A book the reader already keeps is flagged over the summary, with the way
/// to their copy: a second edition stays theirs to add, so nothing is refused.
///
/// Where the book goes is the hero's to say: "Ajouter" puts it on the pile on
/// a tap and offers "En cours" and "Déjà lu" on a long press, each asking for
/// its day; "Envie" puts it on the wishlist; "Guetter", when its edition in
/// the app's language may be awaited, translated or recorded, awaits it
/// instead. The last two close the scan at once, the server told behind it: a
/// reader who scanned it in a shop only wants to know when it comes out. The
/// "+" of the bar offers all of it again, within reach once the hero has
/// scrolled away. What may be awaited follows the language and the format as
/// they are corrected.
/// Everything the review can ask for.
enum ScanReviewAction {
    /// The draft, and the saga as the reader renamed it, if they did.
    case save(BookDraft, SeriesPlacement?)
    case retake
    /// The edition in the app's language awaited instead of the book added:
    /// the scan is then over.
    case awaitEdition(BookDraft, ReleaseFormat)
    /// Onto the wishlist rather than the shelf: the scan is then over.
    case wish(BookDraft)
    /// The language or the format was corrected: what may be awaited is asked again.
    case languageOrFormatChanged(BookLanguage?, BookFormat)
}

struct ScanReviewPage: View {
    @State private var draft: BookDraft
    let ownedCopy: Book?
    let isSaving: Bool
    /// The editions in the app's language this book may be awaited in, as the
    /// server says for its language and format.
    let awaitable: [ReleaseFormat]
    /// The proposals under the genre and saga sheets.
    let loadSubgenres: () async -> [String]
    let loadVocabulary: () async -> BookVocabulary?
    let onAction: (ScanReviewAction) async -> Void

    @State private var editsIdentity = false
    @State private var editsSeries = false
    @State private var editsGenre = false
    @State private var editedField: BookField?
    @State private var choosesLanguage = false
    @State private var renamedSeries: SeriesPlacement?
    /// The status the book is being added as, while its day is asked.
    @State private var askedDate: ReadingStatus?

    init(
        draft: BookDraft,
        ownedCopy: Book? = nil,
        isSaving: Bool,
        awaitable: [ReleaseFormat] = [],
        loadSubgenres: @escaping () async -> [String] = { [] },
        loadVocabulary: @escaping () async -> BookVocabulary? = { nil },
        onAction: @escaping (ScanReviewAction) async -> Void
    ) {
        _draft = State(initialValue: draft)
        self.ownedCopy = ownedCopy
        self.isSaving = isSaving
        self.awaitable = awaitable
        self.loadSubgenres = loadSubgenres
        self.loadVocabulary = loadVocabulary
        self.onAction = onAction
    }

    private var book: Book {
        var book = draft.asReviewedBook
        if let renamedSeries {
            book.series = SeriesMembership(
                id: "",
                name: renamedSeries.name,
                volume: renamedSeries.volume,
                kind: .main
            )
        }
        return book
    }

    /// The app's language, French and English, and the cover's own language
    /// when it plainly said another.
    private var languageChoices: [BookLanguage] {
        let choices = BookLanguage.reviewChoices
        guard let language = draft.language, !choices.contains(language) else { return choices }
        return choices + [language]
    }

    /// The media this book brings to the copy the reader already keeps, which
    /// it then joins rather than doubles — as the server decides: read rather
    /// than heard, in the same language wherever both say. Empty when it
    /// brings none, and saving shelves a second copy.
    private func mediaJoining(_ copy: Book) -> [BookMedium] {
        guard draft.format != .audiobook, copy.format != .audiobook else { return [] }
        if let language = draft.language, let held = copy.language, language != held { return [] }
        return draft.media.filter { !copy.media.contains($0) }
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    /// On the pile at once; under way or read once its day is picked.
    private func add(as status: ReadingStatus) {
        if status == .toRead {
            save(as: .toRead, on: nil)
        } else {
            askedDate = status
        }
    }

    /// Saves the book in the status picked, with the day the reader gave it:
    /// the start of a book under way, the finish of one read — the server
    /// stamps the start of a read book on its finish.
    private func save(as status: ReadingStatus, on day: Date?) {
        var approved = draft
        approved.status = status
        approved.rating = 0
        approved.favorite = false
        approved.startedAt = status == .reading ? day : nil
        approved.finishedAt = status == .read ? day : nil
        Task { await onAction(.save(approved, renamedSeries)) }
    }

    private func wish() {
        Task { await onAction(.wish(draft)) }
    }

    private func awaitEdition(_ format: ReleaseFormat) {
        Task { await onAction(.awaitEdition(draft, format)) }
    }

    /// The three ways onto the shelf, in the order a book goes through them.
    @ViewBuilder private var shelfChoices: some View {
        Button("À lire", systemImage: ReadingStatus.toRead.symbol) { add(as: .toRead) }
            .disabled(!canSave)
            .accessibilityIdentifier("review-save")
        Button("En cours", systemImage: ReadingStatus.reading.symbol) { add(as: .reading) }
            .disabled(!canSave)
            .accessibilityIdentifier("review-save-reading")
        Button("Déjà lu", systemImage: ReadingStatus.read.symbol) { add(as: .read) }
            .disabled(!canSave)
            .accessibilityIdentifier("review-save-read")
    }

    @ViewBuilder private var awaitChoices: some View {
        ForEach(awaitable) { format in
            Button(format.awaitLabel, systemImage: format == .audiobook ? "headphones" : "binoculars") {
                awaitEdition(format)
            }
            .accessibilityIdentifier("review-await-\(format.rawValue)")
        }
    }

    /// Everything the hero offers, in the bar.
    private var addMenu: some View {
        Menu {
            shelfChoices
            Section {
                Button("Liste d'envies", systemImage: "bookmark") { wish() }
                    .disabled(!canSave)
                    .accessibilityIdentifier("review-wish")
            }
            if !awaitable.isEmpty {
                Section { awaitChoices }
            }
        } label: {
            Label("Ajouter", systemImage: "plus")
                .labelStyle(.iconOnly)
        }
        .disabled(isSaving)
        .accessibilityIdentifier("review-add")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                BookHero(book: book) {
                    // Sideways past the width rather than a label cut.
                    ScrollView(.horizontal) {
                        heroButtons
                            .padding(.horizontal, 20)
                    }
                    .scrollIndicators(.hidden)
                    .scrollClipDisabled()
                    .padding(.horizontal, -20)
                }
                VStack(alignment: .leading, spacing: 28) {
                    if let ownedCopy {
                        OwnedCopyBlock(copy: ownedCopy, joining: mediaJoining(ownedCopy))
                    }
                    if let synopsis = draft.synopsis {
                        BookSynopsisBlock(synopsis: synopsis)
                    }
                    if let membership = book.series {
                        SeriesVolumesRow(
                            name: membership.name,
                            volumes: [.owned(book)],
                            currentId: book.id,
                            onOpenSeries: { editsSeries = true },
                            onOpenVolume: { _ in }
                        )
                    }
                    facts
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 32)
            }
        }
        // The bar keeps its edge: its title stays readable over the text
        // scrolled under it, which the colours above the hero blur away.
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Vérifier")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .disabled(isSaving)
        .task(id: [draft.language?.rawValue, draft.format.rawValue]) {
            await onAction(.languageOrFormatChanged(draft.language, draft.format))
        }
        .confirmationDialog("Langue", isPresented: $choosesLanguage, titleVisibility: .visible) {
            ForEach(languageChoices, id: \.self) { language in
                Button(language.label) { draft.language = language }
            }
        }
        .sheet(isPresented: $editsIdentity) {
            ScanIdentitySheet(book: book) { draft.apply($0) }
        }
        .sheet(isPresented: $editsGenre) {
            GenreEditSheet(book: book, loadSubgenres: loadSubgenres) { correction in
                draft.apply(correction)
                return nil
            }
        }
        .sheet(isPresented: $editsSeries) {
            SeriesJoinSheet(book: book, loadVocabulary: loadVocabulary) { correction in
                if case let .set(placement) = correction.series { renamedSeries = placement }
                return nil
            }
        }
        .sheet(item: $editedField) { field in
            FieldEditSheet(book: book, field: field) { correction in
                draft.apply(correction)
                return nil
            }
        }
        .sheet(item: $askedDate) { status in
            ReadingDateSheet(
                title: status == .read ? "Terminé le" : "Commencé le",
                date: .now,
                range: .distantPast...Date.now
            ) { day in
                save(as: status, on: day)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarIconButton(
                    title: "Reprendre",
                    systemImage: "arrow.counterclockwise",
                    role: .cancel,
                    action: { Task { await onAction(.retake) } }
                )
            }
            ToolbarItem(placement: .confirmingAction) {
                addMenu
            }
        }
    }

    // MARK: - Hero

    /// "Ajouter" white, as the book's page sets its next step, "Envie" and
    /// "Guetter" on glass beside it. No GlassEffectContainer: a menu opened
    /// from inside one loses a moving tap on a row over a neighbouring button.
    private var heroButtons: some View {
        HStack(spacing: 8) {
            Menu {
                shelfChoices
            } label: {
                ReviewButtonLabel(title: "Ajouter", systemImage: "plus", showsMenu: true)
            } primaryAction: {
                add(as: .toRead)
            }
            .menuStyle(.button)
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .disabled(!canSave)
            .accessibilityIdentifier("review-hero-add")

            Button(action: wish) {
                ReviewButtonLabel(title: "Envie", systemImage: "bookmark")
            }
            .buttonStyle(.glass)
            .disabled(!canSave)
            .accessibilityIdentifier("review-hero-wish")

            if let format = awaitable.first {
                Group {
                    if awaitable.count > 1 {
                        Menu {
                            awaitChoices
                        } label: {
                            ReviewButtonLabel(title: "Guetter", systemImage: "binoculars", showsMenu: true)
                        }
                        .menuStyle(.button)
                    } else {
                        Button { awaitEdition(format) } label: {
                            ReviewButtonLabel(title: "Guetter", systemImage: "binoculars")
                        }
                    }
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("review-hero-await")
            }
        }
        .font(.subheadline.weight(.semibold))
        .controlSize(.regular)
        .fixedSize()
    }

    // MARK: - Facts

    /// What the cover said, as the book's page tiles it, every tile there to
    /// be corrected; the title and author from the header.
    private var facts: some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: "Informations", detail: String(localized: "titre et auteur"), action: { editsIdentity = true })
                .accessibilityIdentifier("review-identity")
            FactGrid(tiles: factTiles)
        }
    }

    private var factTiles: [FactTile] {
        var tiles = [
            FactTile(
                id: "genre",
                title: "Genre",
                value: book.genre?.label,
                chips: book.subgenres,
                isWide: true,
                showsChevron: true,
                action: { editsGenre = true }
            ),
        ]
        // A saga read off the cover heads its own row; none, and it is
        // joined from here.
        if book.series == nil {
            tiles.append(FactTile(
                id: "series",
                title: "Série",
                value: nil,
                isWide: true,
                placeholder: String(localized: "Aucune"),
                showsChevron: true,
                action: { editsSeries = true }
            ))
        }
        tiles += [
            FactTile(id: "format", title: "Format", value: formatValue),
            FactTile(id: "publisher", title: "Éditeur", value: book.publisher, action: { editedField = .publisher }),
            FactTile(
                id: "firstPublishedIn",
                title: "Parution",
                value: book.firstPublishedIn.map(String.init),
                action: { editedField = .firstPublishedIn }
            ),
            FactTile(
                id: "pageCount",
                title: "Pages",
                value: book.pageCount.map(String.init),
                action: { editedField = .pageCount }
            ),
        ]
        if book.format != .audiobook {
            tiles.append(FactTile(
                id: "isbn13",
                title: "ISBN",
                value: book.isbn13,
                valueFont: .subheadline.weight(.semibold).monospacedDigit(),
                action: { editedField = .isbn13 }
            ))
        }
        // The edition decides which volumes of its saga are out: a French
        // copy taken for the English one drew volumes not translated yet.
        // Presumed in the app's language, switched here.
        tiles.append(FactTile(
            id: "language",
            title: "Langue",
            value: draft.language?.label,
            placeholder: String(localized: "Non renseignée"),
            showsChevron: true,
            chevronSymbol: "chevron.up.chevron.down",
            action: { choosesLanguage = true }
        ))
        return tiles
    }

    /// What the book is and how the reader holds it, as the book's page says
    /// it: "Livre · papier", "Livre audio".
    private var formatValue: String {
        guard book.format != .audiobook, !book.media.isEmpty else { return book.format.label }
        return "\(book.format.label) · \(BookMedium.label(of: book.media).lowercased())"
    }
}

/// A hero button's label, as the book's page sets its own: the symbol at the
/// text's size six points from it, a small chevron after the words where the
/// button opens a menu, one height whatever the symbol.
private struct ReviewButtonLabel: View {
    let title: LocalizedStringKey
    let systemImage: String
    var showsMenu = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .imageScale(.medium)
                .accessibilityHidden(true)
            Text(title)
            if showsMenu {
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 2)
        .frame(height: 24)
    }
}

/// The reader already keeps this book, opening their copy: a warning when
/// saving would shelve a second one, a note when it joins the copy on another
/// medium — paper or screen, it is one book.
private struct OwnedCopyBlock: View {
    let copy: Book
    /// The media saving adds to the copy. Empty when it adds none.
    let joining: [BookMedium]

    var body: some View {
        NavigationLink {
            BookScreen(bookId: copy.id)
                .closesAsPushed()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if joining.isEmpty {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    } else {
                        Image(systemName: "link").foregroundStyle(.tint)
                    }
                }
                .font(.body)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Déjà dans votre bibliothèque")
                        .font(.headline)
                    Text("\(copy.title) · \(copy.status.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Group {
                        if joining.isEmpty {
                            Text("Vous pouvez l'ajouter une seconde fois, pour une autre édition par exemple.")
                        } else {
                            Text("Il rejoindra votre fiche, désormais en \(BookMedium.label(of: copy.media + joining)). Un seul livre, quel que soit le support.")
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("review-owned-copy")
    }
}

private extension BookDraft {
    /// The draft as the book's page would draw it once saved.
    var asReviewedBook: Book {
        Book(
            id: "review",
            title: title,
            authors: authors,
            format: format,
            media: format == .audiobook ? [] : media,
            publisher: publisher,
            firstPublishedIn: firstPublishedIn,
            synopsis: synopsis,
            genre: genre,
            subgenres: subgenres,
            pageCount: pageCount,
            isbn13: isbn13,
            language: language,
            series: series,
            coverURL: coverURL,
            status: status
        )
    }

    /// Lands a correction made on the review page. The saga is never part of
    /// one: it is the server's answer, and stays as the scan resolved it.
    mutating func apply(_ correction: BookCorrection) {
        if let title = correction.title { self.title = title }
        if let authors = correction.authors { self.authors = authors }
        if let format = correction.format { self.format = format }
        if let media = correction.media { self.media = media }
        if let change = correction.publisher { publisher = change.value }
        if let change = correction.firstPublishedIn { firstPublishedIn = change.value }
        if let change = correction.synopsis { synopsis = change.value }
        if let change = correction.genre { genre = change.value }
        if let subgenres = correction.subgenres { self.subgenres = subgenres }
        if let change = correction.pageCount { pageCount = change.value }
        if let change = correction.isbn13 { isbn13 = change.value }
        if let change = correction.language { language = change.value }
    }
}

private extension BookCorrection.Change {
    var value: Value? {
        switch self {
        case let .set(value): value
        case .clear: nil
        }
    }
}

#Preview("Owned already") {
    NavigationStack {
        ScanReviewPage(
            draft: BookDraft(title: "Dune", authors: ["Frank Herbert"], genre: .scienceFiction),
            ownedCopy: Book(id: "dune", title: "Dune", authors: ["Frank Herbert"], status: .read),
            isSaving: false
        ) { _ in }
    }
}

#Preview {
    NavigationStack {
        ScanReviewPage(
            draft: BookDraft(
                title: "Le Nom du vent",
                authors: ["Patrick Rothfuss"],
                publisher: "Bragelonne",
                firstPublishedIn: 2007,
                synopsis: "Kvothe raconte sa propre légende.",
                genre: .fantasy,
                subgenres: ["Roman initiatique"],
                pageCount: 662,
                isbn13: "9782352943556",
                series: SeriesMembership(id: "kkc", name: "Chronique du tueur de roi", volume: 1, kind: .main)
            ),
            isSaving: false,
            awaitable: [.audiobook]
        ) { _ in }
    }
}
