import SwiftUI

/// A friend's move on a book, as the feed draws it: who, what they did, the
/// cover, and the "+" that takes the book onto the reader's pile.
struct FeedEventRow: View {
    let event: FeedEvent
    let onOpen: () -> Void
    let onTake: (BookFormat) async -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    FriendMonogram(name: event.friendName, size: 44)
                    VStack(alignment: .leading, spacing: 3) {
                        sentence
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                        if let detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                    BookCover(book: event.cover, width: 46)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            TakeButton(owned: event.inLibrary, isAdding: false, format: event.format, action: onTake)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .accessibilityIdentifier("news-event")
    }

    private var sentence: Text {
        switch event.kind {
        case .loved: Text("**\(event.friendName)** a adoré **\(event.title)**")
        case .finished: Text("**\(event.friendName)** a terminé **\(event.title)**")
        case .started: Text("**\(event.friendName)** a commencé **\(event.title)**")
        }
    }

    /// Stars and how long ago for a verdict; how many friends began it too for a start.
    private var detail: String? {
        let ago = event.at.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
        switch event.kind {
        case .started:
            return event.alsoStartedBy > 0
                ? String(localized: "Comme \(event.alsoStartedBy) de vos amis")
                : ago
        case .loved, .finished:
            guard let rating = event.rating, rating > 0 else { return ago }
            return "\(UpcomingRelease.stars(rating)) · \(ago)"
        }
    }
}

#Preview("Feed event row") {
    VStack(spacing: 0) {
        ForEach(FeedEvent.previews) { event in
            FeedEventRow(event: event, onOpen: {}, onTake: { _ in })
        }
    }
    .preferredColorScheme(.dark)
}
