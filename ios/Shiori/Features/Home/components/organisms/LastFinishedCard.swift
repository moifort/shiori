import SwiftUI

/// The last book finished, or a word on what will take its place. The card is
/// drawn either way so the reader learns what the dashboard keeps here.
struct LastFinishedCard: View {
    let book: Book?
    let onTapped: (Book) -> Void

    var body: some View {
        if let book {
            filled(book)
        } else {
            WidgetCard(title: "Dernier livre terminé") {
                WidgetEmptyMessage(text: "Terminez un livre pour le retrouver ici.")
            }
            .accessibilityIdentifier("home-last-finished")
        }
    }

    private func filled(_ book: Book) -> some View {
        Button { onTapped(book) } label: {
            // Top-aligned like the library rows: the title starts level with the
            // top of the cover; only the chevron stays centred on the row.
            HStack(alignment: .top, spacing: 14) {
                BookCover(book: book, width: 56)
                VStack(alignment: .leading, spacing: 3) {
                    Text(finishedLine(of: book)).font(.caption).foregroundStyle(.secondary)
                    Text(book.title).font(.headline).lineLimit(2)
                    Text(detailLine(of: book)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    if let rating = book.rating {
                        StarRatingView(rating: rating)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .frame(maxHeight: .infinity)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-last-finished")
    }

    private func finishedLine(of book: Book) -> String {
        guard let finishedAt = book.finishedAt else { return String(localized: "Dernier livre terminé") }
        let days = finishedAt.daysAgo()
        switch days {
        case 0: return String(localized: "Dernier livre terminé · aujourd'hui")
        case 1: return String(localized: "Dernier livre terminé · hier")
        default: return String(localized: "Dernier livre terminé · il y a \(days) j")
        }
    }

    private func detailLine(of book: Book) -> String {
        guard let started = book.startedAt, let finished = book.finishedAt else { return book.authorLine }
        let days = started.daysAgo(from: finished) + 1
        return "\(book.authorLine) · " + String(localized: "lu en \(days) jours")
    }
}
