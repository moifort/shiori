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
    /// The volume label ("Tome 3") shown inside a series section, where the
    /// title alone does not say which volume this is. Absent elsewhere: on the
    /// standalone shelf there is no numbering to explain.
    var volumeLabel: String?
    /// What the book is about. Absent on a book added by hand and on every
    /// Audible import, which draw no genre line at all rather than "Autre".
    var genre: BookGenre?
    /// The one subgenre worth the space: the head of the book's list, which the
    /// scan orders most representative first. The rest stay on the detail screen,
    /// where three pills fit and a row has space for one.
    var subgenre: String?
    /// What kind of object this is. Only an audiobook draws anything: the others
    /// are read, which is what a library is assumed to hold.
    var format: BookFormat = .book
    /// The language of this edition. Absent on every book catalogued before the
    /// scan started reading it off the cover, and left out by the caller inside
    /// a saga section, whose heading already carries it.
    var language: BookLanguage?
    var isFavorite: Bool = false
    var isHidden: Bool = false

    var body: some View {
        // Top-aligned so the first line of text starts level with the cover,
        // whether that line is a volume label or the title itself.
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: cover)
                .overlay(alignment: .topTrailing) {
                    ReadingStatusBadge(status: status)
                        .offset(x: 5, y: -5)
                }

            VStack(alignment: .leading, spacing: 3) {
                if let volumeLabel {
                    Text(volumeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Text(authorLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                // Under the author, where it answers "what is this?" for a title
                // that does not say. Two chips of the same cut, genre then
                // subgenre, and no glyph: the genre's icon was a second thing to
                // decode on a list of twenty different genres, and the word
                // alone is what the eye reads anyway.
                if genre != nil || subgenre != nil {
                    HStack(spacing: 6) {
                        if let genre {
                            chip(genre.label)
                        }
                        if let subgenre {
                            chip(subgenre)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 8)

            // The right column, the same on every row so the eye finds things
            // where it left them: the reader's own judgement on the title's
            // line, then the markers of what the object is.
            VStack(alignment: .trailing, spacing: 6) {
                OpinionMark(rating: rating, isFavorite: isFavorite, font: .caption)
                HStack(spacing: 6) {
                    if let language, language.isForeign {
                        Text(language.flag)
                            .font(.caption)
                            .accessibilityLabel(Text(language.label))
                    }
                    if format == .audiobook {
                        // A recording sits in the same list as the printed books
                        // and reads nothing like one — the cover alone never
                        // says so.
                        Image(systemName: "headphones")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Livre audio"))
                    }
                    if isHidden {
                        // Says the book is excluded from sharing. Only ever an
                        // icon, tucked in the corner: spelling it out on every
                        // row would shout a private choice at anyone glancing
                        // over a shoulder.
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Non partagé"))
                    }
                }
            }
            // Level with the title, whether or not a volume label sits above it.
            .padding(.top, volumeLabel == nil ? 2 : 18)
        }
        // Room for the badge, which overhangs the cover's top edge.
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        // The badge is icon-only, so the status is spoken here rather than
        // read off a glyph.
        .accessibilityValue(Text(status.label))
    }

    /// A word in a capsule, sized for a row: the detail screen's pills would eat
    /// the line.
    private func chip(_ text: String) -> some View {
        Text(text)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(.quaternary, in: Capsule())
    }
}

/// The reading status pinned to a cover's corner. Icon-only, because a 56-point
/// cover leaves no room for a word; the colour carries the state at a glance and
/// the symbol keeps it distinguishable without colour.
private struct ReadingStatusBadge: View {
    let status: ReadingStatus

    private var tint: Color {
        switch status {
        case .toRead: .gray
        case .reading: .blue
        case .read: .green
        }
    }

    var body: some View {
        Image(systemName: status.symbol)
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(tint, in: Circle())
            // A ring in the row's own background lifts the badge off whatever
            // colour the cover happens to be under it.
            .overlay(Circle().strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2))
            .accessibilityHidden(true)
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
            volumeLabel: "Tome 1"
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
            format: .audiobook,
            language: .en
        )
    }
}
