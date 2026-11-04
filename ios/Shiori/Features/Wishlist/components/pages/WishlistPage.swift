import SwiftUI

/// Everything the wishlist's page can ask for.
enum WishlistAction {
    case openEdition(AwaitedEdition)
    case chooseWish(Wish)
    case selectFormat(BookFormat?)
    case refresh
}

/// "Liste d'envies", as the Series tab lays out its shelf: the editions
/// awaited announced for a day, as its "Prochaines sorties" cards; then a
/// rail per way the books came — the editions out, a friend's, the
/// discoveries, the scans — and the editions nobody announced yet. Each cover
/// says where it came from. A section with nothing in it is not drawn.
struct WishlistPage: View {
    let wishlist: Wishlist
    var formats: [BookFormat] = []
    var selectedFormat: BookFormat?
    let isLoading: Bool
    let errorMessage: String?
    let onAction: (WishlistAction) -> Void

    @State private var releaseInView: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                if formats.count > 1 {
                    FilterPills(
                        pills: formats.map { FilterPills.Pill(id: $0.rawValue, label: $0.shelfLabel) },
                        selected: selectedFormat?.rawValue
                    ) { onAction(.selectFormat($0.flatMap(BookFormat.init(rawValue:)))) }
                }
                if !wishlist.upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        RowHeader(title: "Prochaines sorties", style: .inline).padding(.horizontal, 20)
                        releaseRail
                    }
                }
                editionRail("Disponibles", wishlist.released) { _ in String(localized: "Sorti") }
                wishRail("Conseillés par vos amis", wishlist.fromFriends) { $0.originCaption }
                wishRail("Découvertes", wishlist.discovered) { $0.originCaption }
                wishRail("Scannés", wishlist.scanned) {
                    $0.wishedAt.formatted(.dateTime.day().month(.abbreviated))
                }
                editionRail("Pas encore annoncés", wishlist.unannounced) {
                    $0.format == .audiobook ? String(localized: "Audio") : String(localized: "Traduction")
                }
            }
            // Full width even with every section empty, so the empty state
            // laid over the page is not squeezed into a zero-wide column.
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Liste d'envies")
        .refreshable { onAction(.refresh) }
        .overlay { emptyState }
    }

    private var releaseRail: some View {
        VStack(spacing: 10) {
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(wishlist.upcoming) { edition in
                        SeriesReleaseCard(
                            volume: edition.volume,
                            author: edition.authors.first ?? "",
                            isAudio: edition.format == .audiobook,
                            place: edition.place
                        ) { onAction(.openEdition(edition)) }
                        .containerRelativeFrame(.horizontal) { width, _ in
                            wishlist.upcoming.count > 1 ? width - 50 : width - 40
                        }
                        .id(edition.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $releaseInView)
            if wishlist.upcoming.count > 1 {
                HStack(spacing: 6) {
                    ForEach(wishlist.upcoming) { edition in
                        Circle()
                            .fill(edition.id == (releaseInView ?? wishlist.upcoming.first?.id)
                                ? Color.primary : Color.secondary.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier("wishlist-releases")
    }

    @ViewBuilder
    private func editionRail(
        _ title: LocalizedStringKey,
        _ editions: [AwaitedEdition],
        caption: @escaping (AwaitedEdition) -> String
    ) -> some View {
        if !editions.isEmpty {
            rail(title, items: editions.map { edition in
                PosterRow.Item(book: edition.cover, caption: caption(edition)) {
                    onAction(.openEdition(edition))
                }
            })
        }
    }

    @ViewBuilder
    private func wishRail(_ title: LocalizedStringKey, _ wishes: [Wish], caption: @escaping (Wish) -> String) -> some View {
        if !wishes.isEmpty {
            rail(title, items: wishes.map { wish in
                PosterRow.Item(book: wish.cover, caption: caption(wish)) { onAction(.chooseWish(wish)) }
            })
        }
    }

    private func rail(_ title: LocalizedStringKey, items: [PosterRow.Item]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RowHeader(title: title, style: .inline).padding(.horizontal, 20)
            PosterRow(items: items) { _ in }
                .contentMargins(.horizontal, 20, for: .scrollContent)
        }
    }

    @ViewBuilder private var emptyState: some View {
        if wishlist.isEmpty {
            if isLoading {
                ProgressView()
            } else if let errorMessage {
                EmptyState.failure("Liste d'envies indisponible", message: errorMessage) { onAction(.refresh) }
            } else {
                EmptyState(
                    systemImage: "bookmark",
                    title: "Aucune envie",
                    message: "Ajoutez-y un livre depuis Découvrir ou chez un ami, ou guettez sa traduction."
                )
            }
        }
    }
}

extension AwaitedEdition {
    /// Drawn as a saga's next volume on the release card.
    var volume: DiscoveredVolume {
        DiscoveredVolume(
            number: 0,
            title: title,
            date: date,
            isbn13: nil,
            coverURL: coverURL,
            audibleURL: format == .audiobook ? storeURL : nil
        )
    }

    /// Over the card's title: the author, and "Audio" for a recording.
    var place: String {
        let author = authors.first ?? ""
        return format == .audiobook ? "\(author) · \(String(localized: "Audio"))" : author
    }
}

#Preview("Filled") {
    NavigationStack {
        WishlistPage(
            wishlist: .preview,
            formats: [.book, .audiobook],
            isLoading: false,
            errorMessage: nil
        ) { _ in }
    }
    .environment(\.colorScheme, .dark)
}

#Preview("Empty") {
    NavigationStack {
        WishlistPage(wishlist: Wishlist(), isLoading: false, errorMessage: nil) { _ in }
    }
}
