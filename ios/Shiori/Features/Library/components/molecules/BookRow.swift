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
    /// scan started reading it off the cover.
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

                if let rating {
                    StarRatingView(rating: rating)
                        .padding(.top, 1)
                }

                // Under the stars, where it answers "what is this?" for a title
                // that does not say. Icon and word together: the glyph alone
                // would be a riddle on a list of twenty different genres, and
                // the subgenre beside it is what tells two space operas apart.
                if genre != nil || subgenre != nil {
                    HStack(spacing: 6) {
                        if let genre {
                            // `image` rather than `Image(systemName:)`: three genres
                            // have no SF Symbol and come from the asset catalog.
                            Label { Text(genre.label) } icon: { genre.image }
                        }
                        if let subgenre {
                            Text(subgenre)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 1)
                }
            }

            Spacer(minLength: 0)

            // The corner markers, in the order a glance wants them: what the
            // object is, then what the reader chose about it.
            HStack(spacing: 6) {
                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.pink)
                        .accessibilityLabel(Text("Favori"))
                }
                if let language, language.isForeign {
                    Text(language.flag)
                        .font(.caption)
                        .accessibilityLabel(Text(language.label))
                }
                if format == .audiobook {
                    // A recording sits in the same list as the printed books and
                    // reads nothing like one — the cover alone never says so.
                    Image(systemName: "headphones")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Livre audio"))
                }
                if isHidden {
                    // Says the book is excluded from sharing. Only ever an icon,
                    // tucked in the corner: spelling it out on every row would
                    // shout a private choice at anyone glancing over a shoulder.
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(Text("Non partagé"))
                }
            }
        }
        // Room for the badge, which overhangs the cover's top edge.
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        // The badge is icon-only, so the status is spoken here rather than
        // read off a glyph.
        .accessibilityValue(Text(status.label))
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
