import SwiftUI

/// A book out lately among what the reader follows, as "Sorti" lists it: the
/// mark of where it comes from, its title, why the reader is told and the day
/// it came out, and its cover.
struct ReleasedRow: View {
    let release: UpcomingRelease
    let day: Date
    var onOpen: (() -> Void)?

    var body: some View {
        Button { onOpen?() } label: {
            HStack(spacing: 14) {
                mark
                VStack(alignment: .leading, spacing: 3) {
                    Text(release.title ?? release.cover.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                BookCover(book: release.cover, width: 46)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(onOpen != nil)
        .accessibilityIdentifier("news-released")
    }

    private var detail: String {
        [release.reason, day.formatted(.dateTime.day().month(.abbreviated))]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    @ViewBuilder
    private var mark: some View {
        switch release.source {
        case .author:
            if let url = release.author?.portraitURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    FriendMonogram(name: release.author?.name ?? release.authors.first ?? "", size: 44)
                }
                .frame(width: 44, height: 44)
                .clipShape(.circle)
            } else {
                FriendMonogram(name: release.author?.name ?? release.authors.first ?? "", size: 44)
            }
        case .saga:
            symbol("books.vertical.fill")
        case .awaited:
            symbol(release.format == .audiobook ? "headphones" : "character.book.closed.fill")
        case .narrator:
            symbol("mic.fill")
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 17, weight: .semibold))
            .frame(width: 44, height: 44)
            .background(Color(.secondarySystemGroupedBackground), in: .circle)
            .accessibilityHidden(true)
    }
}

#Preview("Released rows") {
    VStack(spacing: 0) {
        ForEach(UpcomingRelease.releasedPreviews) { release in
            ReleasedRow(release: release, day: .now.addingTimeInterval(-6 * 86400))
        }
    }
    .preferredColorScheme(.dark)
}
