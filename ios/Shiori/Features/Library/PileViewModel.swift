import Foundation
import SwiftUI

/// Owns "Pile à lire": the pile cut into the reasons to read its books, and
/// its format and genre pills. It opens on the snapshot of its last visit, refreshed
/// silently underneath.
@MainActor
@Observable
final class PileViewModel {
    /// - Parameters:
    ///   - view: the view it was opened in, a genre page's or the format the
    ///     entry screen was narrowed to, which its pill shows chosen.
    ///   - caching: off in tests, which must neither read nor leave a snapshot.
    init(client: LibraryClient, view: ShelvesView = ShelvesView(), caching: Bool = true) {
        self.client = client
        self.caching = caching
        self.view = view
        openedGenre = view.genre
        let pile = Self.cache(for: view, caching: caching)?.read() ?? Pile()
        self.pile = pile
        formats = pile.formats
        genres = pile.genres
    }

    private let client: LibraryClient
    private let caching: Bool

    private(set) var pile: Pile
    private(set) var view: ShelvesView
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The pills offered, kept from the view without a pill: choosing one,
    /// of either row, must not take the others away.
    private(set) var formats: [BookFormat] = []
    private(set) var genres: [BookGenre] = []
    /// The genre page it was opened from, whose genre is not the pills' to
    /// change.
    private let openedGenre: BookGenre?

    private var loaded = false
    private var generation = 0

    /// The format pills, shown only when there are two to choose from.
    var shownFormats: [BookFormat] {
        formats.count > 1 ? formats : []
    }

    /// The genre pills, shown only when there are two to choose from and the
    /// pile was not opened from a genre page.
    var shownGenres: [BookGenre] {
        openedGenre == nil && genres.count > 1 ? genres : []
    }

    private static func cache(for view: ShelvesView, caching: Bool) -> SnapshotCache<Pile>? {
        guard caching else { return nil }
        return SnapshotCache("pile-\(view.cacheKey)", version: 2)
    }

    /// A format pill; nil is "Tout".
    func select(format: BookFormat?) async {
        guard view.format != format else { return }
        view.format = format
        if let snapshot = Self.cache(for: view, caching: caching)?.read() { pile = snapshot }
        await load()
    }

    /// A genre pill; nil is "Tout".
    func select(genre: BookGenre?) async {
        guard view.genre != genre else { return }
        view.genre = genre
        if let snapshot = Self.cache(for: view, caching: caching)?.read() { pile = snapshot }
        await load()
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// Loads the view. A failure over sections already on screen says
    /// nothing: they stay as they were, and a pull tries again.
    func load() async {
        generation += 1
        let requested = generation
        let asked = view
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await client.pile(asked)
            guard requested == generation else { return }
            withAnimation(pile.sections.isEmpty ? nil : .smooth) {
                pile = fetched
                let unpicked = asked.format == nil && asked.genre == openedGenre
                if unpicked || formats.isEmpty { formats = fetched.formats }
                if unpicked || genres.isEmpty { genres = fetched.genres }
            }
            loaded = true
            CoverImages.prefetch(fetched.sections.flatMap { $0.picks.compactMap(\.book.coverURL) })
            if let cache = Self.cache(for: asked, caching: caching) {
                Task.detached { cache.write(fetched) }
            }
        } catch {
            guard requested == generation else { return }
            isLoading = false
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
            return
        }
        isLoading = false
    }
}
