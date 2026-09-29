import SwiftUI

/// A book somebody else holds, or nobody yet — a friend's copy, a suggestion —
/// drawn the way the book page draws the reader's own, with nothing to tap:
/// the cover, the title, the author and the saga, then the genre and its tags.
/// A page may add a way out to the store — a quiet tag in the corner with its
/// arrow, as the book page draws Audible's — the way to its saga where the
/// book page has it, and rows of its own under the facts.
struct ReadOnlyBookHeader<Extra: View>: View {
    /// A store the book can be opened in: its name on the tag, and where. A
    /// store with a colour of its own — Audible — draws its tag in it.
    struct StoreLink {
        let name: String
        let url: URL
        var tint: Color? = nil
    }

    let book: Book
    var storeLink: StoreLink?
    /// Opens the book's saga, from the row the book page draws under the
    /// cover. Nil draws no row: the saga is still named beside the cover.
    var onOpenSeries: (() -> Void)?
    @ViewBuilder var extra: Extra

    var body: some View {
        Section {
            HStack(alignment: .top, spacing: 14) {
                BookCover(book: book, width: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title).font(.headline)
                    Text(book.authorLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let series = book.series {
                        Text(verbatim: "\(series.name) · \(series.label)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let narratorLine = book.narratorLine {
                        Text("Lu par \(narratorLine)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 6) {
                        if let language = book.language, language.isForeign {
                            LanguageTag(language: language)
                        }
                        if let durationLabel = book.durationLabel {
                            Pill(text: durationLabel, systemImage: "clock")
                        }
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // In the bottom corner, level with the foot of the cover: a way
            // out of Shiori, kept apart from what the book is.
            .overlay(alignment: .bottomTrailing) {
                if let storeLink {
                    Link(destination: storeLink.url) {
                        Pill(text: storeLink.name, tint: storeLink.tint, trailingSystemImage: "arrow.up.right")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("Ouvrir dans \(storeLink.name)"))
                    .accessibilityIdentifier("book-store-link")
                }
            }
            .padding(.vertical, 2)
            // The rule under the cover runs the whole width, as on the book page.
            .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
            .copyable([
                CopyableValue(title: "Copier le titre", value: book.title),
                CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            ])

            if let series = book.series, let onOpenSeries {
                SeriesLinkRow(name: series.name, action: onOpenSeries)
                    .accessibilityIdentifier("book-series")
            }

            if let genre = book.genre {
                Label {
                    VStack(alignment: .leading, spacing: 8) {
                        LabeledContent("Genre") {
                            HStack(spacing: 4) {
                                genre.image.imageScale(.small)
                                Text(genre.label)
                            }
                        }
                        if !book.subgenres.isEmpty {
                            TagList(tags: book.subgenres, systemImage: "tag")
                        }
                    }
                } icon: {
                    Image(systemName: "books.vertical").foregroundStyle(.secondary)
                }
            }
            if let publisher = book.publisher {
                LabeledInfoRow(title: "Éditeur", value: publisher, icon: "building.2")
            }
            if let year = book.firstPublishedIn {
                LabeledInfoRow(title: "Première parution", value: String(year), icon: "calendar")
            }
            if let pages = book.pageCount {
                LabeledInfoRow(title: "Pages", value: String(pages), icon: "doc.plaintext")
            }
            extra
        }
    }
}

extension ReadOnlyBookHeader where Extra == EmptyView {
    init(book: Book, storeLink: StoreLink? = nil, onOpenSeries: (() -> Void)? = nil) {
        self.init(book: book, storeLink: storeLink, onOpenSeries: onOpenSeries) { EmptyView() }
    }
}

/// A summary, folded past a few hundred words as the book page folds it.
struct ReadOnlySynopsisSection: View {
    let synopsis: String
    @State private var expanded = false

    private static let wordLimit = 120

    var body: some View {
        let words = synopsis.split(whereSeparator: \.isWhitespace)
        let folded = words.count > Self.wordLimit && !expanded
        Section("Résumé") {
            Text(folded ? words.prefix(Self.wordLimit).joined(separator: " ") + "…" : synopsis)
                .font(.callout)
                .copyable(synopsis)
            if words.count > Self.wordLimit {
                Button(folded ? "Lire la suite" : "Réduire") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.callout)
            }
        }
    }
}
