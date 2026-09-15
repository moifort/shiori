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
            }

            Spacer(minLength: 0)

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
            isHidden: true
        )
        BookRow(
            title: "Piranesi",
            authorLine: "Susanna Clarke",
            cover: Book(id: "3", title: "Piranesi", authors: ["Susanna Clarke"], status: .toRead),
            status: .toRead,
            rating: nil
        )
    }
}
