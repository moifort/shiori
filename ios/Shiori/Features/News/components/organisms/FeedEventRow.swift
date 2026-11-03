import SwiftUI

/// A friend's move on a book, as the feed draws it: who, what they did, the
/// cover, and the "+" that takes the book onto the reader's pile. Friends who
/// made the same move on the same story share the line, their faces stacked.
struct FeedEventRow: View {
    let event: FeedEvent
    /// The other friends who made the same move, the latest first.
    var others: [FeedEvent] = []
    let onOpen: () -> Void
    let onTake: (BookFormat) async -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                HStack(spacing: 14) {
                    faces
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

    @ViewBuilder
    private var faces: some View {
        if let second = others.first {
            ZStack(alignment: .bottomTrailing) {
                AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                AccountAvatarView(avatar: second.avatar, firstName: second.friendName, size: 32)
                    .padding(2)
                    .background(Color(.systemBackground), in: .circle)
                    .offset(x: 2, y: 2)
            }
            .frame(width: 44, height: 44)
        } else {
            AccountAvatarView(avatar: event.avatar, firstName: event.friendName, size: 44)
        }
    }

    private var sentence: Text {
        guard let second = others.first else { return single }
        let first = event.friendName
        let other = second.friendName
        let rest = others.count - 1
        switch (event.kind, rest) {
        case (.loved, 0): return Text("**\(first)** et **\(other)** ont adoré **\(event.title)**")
        case (.finished, 0): return Text("**\(first)** et **\(other)** ont terminé **\(event.title)**")
        case (.started, 0): return Text("**\(first)** et **\(other)** ont commencé **\(event.title)**")
        case (.loved, 1): return Text("**\(first)**, **\(other)** et 1 autre ont adoré **\(event.title)**")
        case (.finished, 1): return Text("**\(first)**, **\(other)** et 1 autre ont terminé **\(event.title)**")
        case (.started, 1): return Text("**\(first)**, **\(other)** et 1 autre ont commencé **\(event.title)**")
        case (.loved, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont adoré **\(event.title)**")
        case (.finished, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont terminé **\(event.title)**")
        case (.started, _): return Text("**\(first)**, **\(other)** et \(rest) autres ont commencé **\(event.title)**")
        }
    }

    private var single: Text {
        switch event.kind {
        case .loved: Text("**\(event.friendName)** a adoré **\(event.title)**")
        case .finished: Text("**\(event.friendName)** a terminé **\(event.title)**")
        case .started: Text("**\(event.friendName)** a commencé **\(event.title)**")
        }
    }

    /// Stars and how long ago for a verdict; how many friends began it too for a start.
    /// Shared by several friends, how long ago the latest did it.
    private var detail: String? {
        let ago = event.at.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
        guard others.isEmpty else { return ago }
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
        FeedEventRow(event: FeedEvent.previews[1], others: Array(FeedEvent.sameStartPreviews), onOpen: {}, onTake: { _ in })
    }
    .preferredColorScheme(.dark)
}
