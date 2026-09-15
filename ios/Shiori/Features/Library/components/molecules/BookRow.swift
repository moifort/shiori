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
    /// Named on the row only when it is not a plain book, which is nearly every
    /// row: a label repeated down the whole list would say nothing.
    var format: BookFormat = .book
    /// The volume label ("Tome 3") shown inside a series section, where the
    /// title alone does not say which volume this is. Absent elsewhere: on the
    /// standalone shelf there is no numbering to explain.
    var volumeLabel: String?
    var isHidden: Bool = false

    private var caption: String? {
        let parts = [format == .book ? nil : format.label, volumeLabel].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            BookCover(book: cover)

            VStack(alignment: .leading, spacing: 3) {
                if let caption {
                    Text(caption)
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

                HStack(spacing: 8) {
                    Label(status.label, systemImage: status.symbol)
                        .font(.caption)
                        .foregroundStyle(status == .read ? Color.green : .secondary)
                        .labelStyle(.titleAndIcon)

                    if let rating {
                        StarRatingView(rating: rating)
                    }

                    if isHidden {
                        // Says the book is excluded from sharing. Only ever an
                        // icon: spelling it out on every row would shout a
                        // private choice at anyone glancing over a shoulder.
                        Image(systemName: "eye.slash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(Text("Non partagé"))
                    }
                }
                .padding(.top, 1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
            format: .audiobook,
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
