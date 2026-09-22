import SwiftUI

/// A book somebody else holds, or nobody yet — a friend's copy, a suggestion —
/// drawn the way the book page draws the reader's own, with nothing to tap:
/// the cover, the title, the author and the saga, then the genre and its tags.
struct ReadOnlyBookHeader: View {
    let book: Book

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
            .padding(.vertical, 2)
            .copyable([
                CopyableValue(title: "Copier le titre", value: book.title),
                CopyableValue(title: "Copier l'auteur", value: book.authors.joined(separator: ", ")),
            ])

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
        }
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
