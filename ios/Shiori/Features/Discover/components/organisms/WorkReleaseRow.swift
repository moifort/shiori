import SwiftUI

/// One work announced or just out, as a saga's next volume is drawn: its cover,
/// the saga it opens if any, its title, when it comes or came out in words,
/// and the calendar leaf on the trailing edge.
struct WorkReleaseRow: View {
    let work: DiscoveredWork
    let author: String
    let isAudio: Bool
    let isOut: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: Book(
                id: "release-\(work.id)",
                title: work.title,
                authors: [author],
                format: isAudio ? .audiobook : .book,
                coverURL: work.coverURL,
                status: .toRead
            ))
            VStack(alignment: .leading, spacing: 3) {
                if let saga {
                    Text(saga)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(work.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                // The day still to come is the calendar leaf's to say: the
                // line says only that a work is out, or announced with no date.
                if isOut || work.date == nil {
                    Group {
                        if let date = work.date {
                            Text(ReleaseDateText.out(date))
                        } else {
                            Text(isOut ? "Disponible" : "Annoncé")
                        }
                    }
                    .foregroundStyle(isOut ? Color.accentColor : .orange)
                    .font(.subheadline.weight(.medium))
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let date = work.date { ReleaseDateBadge(date: date) }
        }
        .padding(.vertical, 4)
    }

    /// "Dragon Blood · Tome 2", or the saga alone.
    private var saga: String? {
        guard let name = work.seriesName else { return nil }
        guard let volume = work.volume else { return name }
        return String(localized: "\(name) · Tome \(volume)")
    }
}

#Preview {
    List {
        WorkReleaseRow(work: AuthorDiscovery.preview.next!, author: "Matt Dinniman", isAudio: true, isOut: false)
    }
}
