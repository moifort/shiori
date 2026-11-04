import SwiftUI

/// A book out lately among what the reader follows, as the feed lists it, the
/// way the book's page heads it: the cover first, AUDIO and a foreign
/// language tagged in its corner; the series and volume above the title, the
/// binoculars beside it for an edition awaited, the author, the day it came
/// out. A narrator or an author the reader follows signs it at its foot, their
/// face and name; the "…" at the end.
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
                    BookCover(book: item.cover, width: Self.coverWidth, showsFormatBadge: false)
                        .overlay(alignment: .topTrailing) {
                            CoverTags(language: item.language, isAudio: item.format == .audiobook)
                                .padding(4)
                        }
                    VStack(alignment: .leading, spacing: 0) {
                        if let seriesLine = item.seriesLine {
                            Text(seriesLine)
                                .font(.footnote)
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineLimit(1)
                                .padding(.bottom, 2)
                        }
                        title
                        if let author = item.authors.first {
                            Text(author)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .padding(.top, 1)
                        }
                        Text(dayText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 5)
                        if hasSignature {
                            Spacer(minLength: 10)
                            signature
                        }
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

    private var title: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(item.shownTitle)
                .font(.headline)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if item.isAwaited {
                Image(systemName: "binoculars")
                    .font(.footnote.weight(.semibold))
                    .accessibilityLabel(Text("Suivi"))
            }
        }
    }

    /// "Aujourd'hui", else the day and the month in full: "28 octobre".
    private var dayText: String {
        guard !Calendar.current.isDateInToday(item.day) else { return String(localized: "Aujourd'hui") }
        return item.day.formatted(.dateTime.day().month(.wide))
    }

    // MARK: - Signature

    /// A person brought it: the narrator who lent their voice, the author.
    private var hasSignature: Bool {
        switch item {
        case .narrator: true
        case let .release(release, _): release.source == .author || release.source == .narrator
        }
    }

    private var signature: some View {
        HStack(spacing: 7) {
            mark
                .frame(width: 22, height: 22)
            signatureText
                .font(.footnote.weight(.semibold))
                .lineLimit(1)
        }
    }

    private var signatureText: Text {
        switch item {
        case let .narrator(news, _):
            Text(verbatim: news.narrator)
        case let .release(release, _):
            Text(verbatim: release.source == .narrator
                ? release.narrator ?? ""
                : release.author?.name ?? release.authors.first ?? "")
        }
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
            case .saga, .awaited:
                EmptyView()
            case .narrator:
                FriendMonogram(name: release.narrator ?? "", size: 22)
            }
        }
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
