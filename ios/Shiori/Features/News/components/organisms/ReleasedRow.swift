import SwiftUI

/// A book out lately among what the reader follows, as the feed lists it, at
/// a friend's row's height: the cover at full height on the left; the series
/// and volume above the title, the binoculars beside it for an edition
/// awaited, the author, then the edition's tags (a foreign language, AUDIO).
/// No day: the period heading above says it. A narrator or an author the
/// reader follows signs it at its foot, their face and name. No "…": sliding
/// the row to the left opens its menu.
struct ReleasedRow: View {
    let item: ReleasedItem
    var owned = false
    var wished = false
    var awaited = false
    var onOpen: (() -> Void)?
    let onAdd: (CopiedStatus, BookFormat) async -> Void
    let onWish: () async -> Void
    let onAwait: (ReleaseFormat) -> Void

    /// The height of the text beside the cover, which the cover stretches to
    /// so its bottom sits level with the last line.
    @State private var textHeight: CGFloat?

    /// The friend row's, so the feed's lines are one height.
    static let coverHeight = FeedEventRow.coverHeight

    var body: some View {
        opening
            .swipeOpensMenu(
                .newsRow(
                    format: item.format, owned: owned, wished: wished, awaited: awaited,
                    onAdd: onAdd, onWish: onWish, onAwait: onAwait
                )
            )
            .accessibilityIdentifier("news-released")
    }

    /// The row opens what it can: its author, its narrator. A volume of a
    /// series or an edition awaited opens nothing yet, but still slides.
    @ViewBuilder
    private var opening: some View {
        if let onOpen {
            Button(action: onOpen) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: item.cover, showsFormatBadge: false, minHeight: max(textHeight ?? 0, Self.coverHeight))
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
                if !tags.isEmpty {
                    tags
                        .fixedSize()
                        .padding(.top, 3)
                }
                if hasSignature {
                    Spacer(minLength: 6)
                    signature
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.coverHeight, alignment: .topLeading)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(.rect)
    }

    private var tags: CoverTags {
        CoverTags(language: item.language, isAudio: item.format == .audiobook, isFrosted: false)
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
