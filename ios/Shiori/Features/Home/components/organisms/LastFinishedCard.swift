import SwiftUI

struct LastFinishedCard: View {
    let book: Book
    let onTapped: () -> Void

    var body: some View {
        Button(action: onTapped) {
            HStack(spacing: 14) {
                BookCover(book: book, width: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(finishedLine).font(.caption).foregroundStyle(.secondary)
                    Text(book.title).font(.headline).lineLimit(2)
                    Text(detailLine).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if let rating = book.rating {
                        StarRatingView(rating: rating)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-last-finished")
    }

    private var finishedLine: String {
        guard let finishedAt = book.finishedAt else { return String(localized: "Dernier livre terminé") }
        let days = finishedAt.daysAgo()
        switch days {
        case 0: return String(localized: "Dernier livre terminé · aujourd'hui")
        case 1: return String(localized: "Dernier livre terminé · hier")
        default: return String(localized: "Dernier livre terminé · il y a \(days) j")
        }
    }

    private var detailLine: String {
        guard let started = book.startedAt, let finished = book.finishedAt else { return book.authorLine }
        let days = started.daysAgo(from: finished) + 1
        return "\(book.authorLine) · " + String(localized: "lu en \(days) jours")
    }
}
