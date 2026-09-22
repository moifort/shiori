import SwiftUI

/// One book in a list: its cover, what it is, and where the reader stands with
/// it. Primitive-first — it takes the values it draws, not a view model — so it
/// previews without a network and reads the same in every list that uses it.
struct BookRow: View {
    let title: String
    let authorLine: String
    let cover: Book
    let status: ReadingStatus
    let rating: Int?
    /// The stars are the saga's, lent to a volume the reader left unrated:
    /// drawn grey, so a judgement given is told from one lent.
    var ratingIsInherited: Bool = false
    /// The volume label ("Tome 3") shown inside a series section, where the
    /// title alone does not say which volume this is. Absent elsewhere: on the
    /// standalone shelf there is no numbering to explain.
    var volumeLabel: String?
    /// The saga the book belongs to, drawn as a tag with its volume where the
    /// list is not sectioned by saga — the only place left to say it.
    var series: SeriesMembership?
    /// The reading status, drawn as a tag in the row's top corner where the
    /// list is not already sectioned by it. Nil leaves it to the heading above.
    var statusTag: ReadingStatus?
    /// What the book is about. Absent on a book added by hand and on every
    /// Audible import, which draw no genre line at all rather than "Autre".
    var genre: BookGenre?
    /// The one subgenre worth the space: the head of the book's list, which the
    /// scan orders most representative first. The rest stay on the detail screen,
    /// where three pills fit and a row has space for one.
    var subgenre: String?
    /// The language of this edition. Absent on every book catalogued before the
    /// scan started reading it off the cover, and left out by the caller inside
    /// a saga section, whose heading already carries it.
    var language: BookLanguage?
    var isFavorite: Bool = false
    var isHidden: Bool = false
    /// How far into a recording the player got, already formatted — "42 %".
    /// Passed only for a recording under way, and drawn as a chip beside the
    /// status, in its colour.
    var listeningProgress: String?

    /// Between the card's edges and the row's content — the list's own inset
    /// on an iPhone, stated here so the separator can span it.
    private static let horizontalInset: CGFloat = 16

    var body: some View {
        // Top-aligned so the first line of text starts level with the cover,
        // whether that line is a volume label or the title itself.
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: cover)

            VStack(alignment: .leading, spacing: 3) {
                // The marks share the first line with the text rather than
                // standing in a column of their own: level with the top of the
                // cover on every row, and the author and the chips below keep
                // the whole width instead of being squeezed beside them.
                HStack(alignment: .top, spacing: 8) {
                    if let volumeLabel {
                        Text(volumeLabel)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        titleText
                    }
                    Spacer(minLength: 0)
                    marks
                }
                if volumeLabel != nil {
                    titleText
                }
                Text(authorLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)


                // Where it sits in a saga: a fact about this copy, ahead of
                // what the book is.
                if series != nil {
                    HStack(spacing: 6) {
                        if let series {
                            // Grey, because a saga is a name and not a kind of
                            // book: tinting it would read as one more genre.
                            chip("\(series.name) · \(series.label)", tint: .secondary)
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.top, 1)
                }

                // Under the author, where it answers "what is this?" for a title
                // that does not say. Two chips of the same cut, genre then
                // subgenre, and no glyph: the genre's icon was a second thing to
                // decode on a list of twenty different genres, and the word
                // alone is what the eye reads anyway.
                if genre != nil || subgenre != nil {
                    HStack(spacing: 6) {
                        if let genre {
                            chip(genre.label, tint: genre.tint)
                        }
                        if let subgenre {
                            // The same hue as the genre it refines, because it
                            // refines it: two colours on one line would read as
                            // two unrelated facts.
                            chip(subgenre, tint: genre?.tint ?? .secondary)
                        }
                    }
                    .font(.caption2)
                    .lineLimit(1)
                    .padding(.top, 1)
                }
            }
        }
        // Tight, because a library is read by scanning many rows at once.
        .padding(.vertical, 4)
        // The separator runs from one edge of the card to the other: a rule
        // starting under the title cuts the cover column off from the list it
        // belongs to. The inset is pinned rather than left to the list, so the
        // guides below know exactly how far the card's edges are.
        .listRowInsets(.horizontal, Self.horizontalInset)
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] - Self.horizontalInset }
        .alignmentGuide(.listRowSeparatorTrailing) { $0[.trailing] + Self.horizontalInset }
        .accessibilityElement(children: .combine)
        // Spoken even where no tag draws it: a heading above the row is not
        // read with it.
        .accessibilityValue(statusTag == nil ? Text(status.label) : Text(""))
    }

    private var titleText: some View {
        Text(title)
            .font(.body.weight(.medium))
            .lineLimit(2)
    }

    /// Everything the row says about the object and about the reader's
    /// judgement, on one line in the top corner — the same place on every row,
    /// so the eye finds it where it left it.
    private var marks: some View {
        HStack(spacing: 6) {
            if let language, language.isForeign {
                LanguageTag(language: language)
            }
            if isHidden {
                // Says the book is excluded from sharing. Only ever an icon,
                // tucked in the corner: spelling it out on every row would
                // shout a private choice at anyone glancing over a shoulder.
                Image(systemName: "eye.slash")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Non partagé"))
            }
            OpinionMark(
                rating: rating,
                isFavorite: isFavorite,
                font: .caption,
                ratingIsInherited: ratingIsInherited
            )
            // How far into a recording, beside where the reader stands: the
            // two say the same thing, one more precisely.
            if let listeningProgress {
                chip(listeningProgress, tint: ReadingStatus.reading.tint)
                    .font(.caption2)
                    .accessibilityLabel(Text("Écouté à \(listeningProgress)"))
            }
            // Where the reader stands, in the corner the eye returns to on
            // every row. A recording says what it is on its cover instead.
            if let statusTag {
                // A dropped book says so by its mark alone: the word would read
                // as a verdict repeated on every row.
                if statusTag == .dropped {
                    ReadingStatusBadge(status: .dropped)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(statusTag.label))
                } else {
                    chip(statusTag.shelfTitle, tint: statusTag.tint)
                        .font(.caption2)
                }
            }
        }
        .font(.caption)
        .fixedSize()
    }

    /// A word in a capsule, sized for a row: the detail screen's pills would eat
    /// the line. Tinted rather than grey — a shelf of identical grey chips is a
    /// texture, and the colour is what lets the eye find the fantasy among the
    /// essays without reading a word.
    private func chip(_ text: String, tint: Color) -> some View {
        Text(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .foregroundStyle(tint)
            .background(tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    List {
        BookRow(
            title: "Le Nom du vent",
            authorLine: "Patrick Rothfuss",
            cover: Book(id: "1", title: "Le Nom du vent", authors: ["Patrick Rothfuss"], status: .reading),
            status: .reading,
            rating: nil,
            series: SeriesMembership(id: "s1", name: "Chronique du tueur de roi", volume: 1, kind: .main),
            statusTag: .reading
        )
        BookRow(
            title: "La Peur du sage",
            authorLine: "Patrick Rothfuss",
            cover: Book(id: "2", title: "La Peur du sage", authors: ["Patrick Rothfuss"], status: .read),
            status: .read,
            rating: 5,
            volumeLabel: "Tome 2",
            isFavorite: true,
            isHidden: true
        )
        BookRow(
            title: "Piranesi",
            authorLine: "Susanna Clarke",
            cover: Book(id: "3", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead),
            status: .toRead,
            rating: nil,
            genre: .literaryFiction,
            subgenre: "Réalisme magique"
        )
        BookRow(
            title: "Dune",
            authorLine: "Frank Herbert",
            cover: Book(id: "4", title: "Dune", authors: ["Frank Herbert"], status: .reading),
            status: .reading,
            rating: nil,
            genre: .scienceFiction,
            subgenre: "Space opera",
            language: .en
        )
    }
}
