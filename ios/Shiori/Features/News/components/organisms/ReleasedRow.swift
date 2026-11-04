import SwiftUI

/// A book out lately among what the reader follows, as "Sorti" lists it: the
/// cover first, its title and author at the cover's top, AUDIO framed when it
/// is a recording, why the reader is told beneath; at its foot the signature,
/// who brought it and the day; the "…" at the end.
struct ReleasedRow: View {
    let item: ReleasedItem
    var owned = false
    var wished = false
    var awaited = false
    var onOpen: (() -> Void)?
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    let onWish: () async -> Void
    let onAwait: (ReleaseFormat) -> Void

    private static let coverWidth: CGFloat = 72

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Button { onOpen?() } label: {
                HStack(alignment: .top, spacing: 14) {
                    BookCover(book: item.cover, width: Self.coverWidth)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        authorLine
                            .padding(.top, 1)
                        if let subtitle = item.subtitle {
                            Text(subtitle)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.top, 5)
                        }
                        Spacer(minLength: 10)
                        signature
                    }
                    .frame(maxWidth: .infinity, minHeight: Self.coverWidth * 1.5, alignment: .topLeading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .allowsHitTesting(onOpen != nil)
            NewsRowMenu(
                format: item.format, owned: owned, wished: wished, awaited: awaited,
                onAdd: onAdd, onWish: onWish, onAwait: onAwait
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .accessibilityIdentifier("news-released")
    }

    private var authorLine: some View {
        HStack(spacing: 6) {
            if let author = item.authors.first {
                Text(author)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            CoverTags(language: item.language, isAudio: item.format == .audiobook, isFrosted: false)
        }
    }

    // MARK: - Signature

    private var signature: some View {
        HStack(spacing: 7) {
            mark
                .frame(width: 22, height: 22)
            (signatureText + Text(dayText).foregroundStyle(.secondary))
                .font(.footnote)
                .lineLimit(2)
        }
    }

    private var signatureText: Text {
        switch item {
        case let .narrator(news, _):
            return Text("**\(news.narrator)** prête sa voix")
        case let .release(release, _):
            switch release.source {
            case .author:
                return Text("**\(release.author?.name ?? release.authors.first ?? "")** nouveau livre")
            case .saga:
                return Text("**\(release.seriesName ?? release.title ?? "")** nouveau tome")
            case .awaited:
                return Text("**Guetté**")
            case .narrator:
                return Text("**\(release.narrator ?? "")** prête sa voix")
            }
        }
    }

    /// " · 15 oct.", nothing for today: the section says it.
    private var dayText: String {
        guard !Calendar.current.isDateInToday(item.day) else { return "" }
        return " · " + item.day.formatted(.dateTime.day().month(.abbreviated))
    }

    @ViewBuilder
    private var mark: some View {
        switch item {
        case let .narrator(news, _):
            FriendMonogram(name: news.narrator, size: 22)
        case let .release(release, _):
            switch release.source {
            case .author:
                if let url = release.author?.portraitURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        FriendMonogram(name: release.author?.name ?? release.authors.first ?? "", size: 22)
                    }
                    .clipShape(.circle)
                } else {
                    FriendMonogram(name: release.author?.name ?? release.authors.first ?? "", size: 22)
                }
            case .saga:
                symbol("square.stack.fill")
            case .awaited:
                symbol(release.format == .audiobook ? "headphones" : "character.book.closed.fill")
            case .narrator:
                FriendMonogram(name: release.narrator ?? "", size: 22)
            }
        }
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 10, weight: .semibold))
            .frame(width: 22, height: 22)
            .background(Color(.secondarySystemGroupedBackground), in: .circle)
            .accessibilityHidden(true)
    }
}

#Preview("Released rows") {
    ScrollView {
        VStack(spacing: 0) {
            ForEach(UpcomingRelease.releasedPreviews) { release in
                ReleasedRow(
                    item: .release(release, day: .now.addingTimeInterval(-6 * 86400)),
                    onAdd: { _, _ in }, onWish: {}, onAwait: { _ in }
                )
            }
            ReleasedRow(item: .narrator(.preview, day: .now), onAdd: { _, _ in }, onWish: {}, onAwait: { _ in })
        }
    }
    .preferredColorScheme(.dark)
}
