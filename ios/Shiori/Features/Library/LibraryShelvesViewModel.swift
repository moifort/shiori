import Foundation
import SwiftUI

/// Owns the Library tab's entry screen — or a genre page, which is the same
/// screen narrowed to a genre — and its one load. It opens on the snapshot of
/// its last visit, so the rails are there on the first frame and refreshed
/// silently underneath.
@MainActor
@Observable
final class LibraryShelvesViewModel {
    /// - Parameters:
    ///   - genre: the genre page this is, nil for the entry screen.
    ///   - caching: off in tests, which must neither read nor leave a snapshot.
    init(client: LibraryClient, genre: BookGenre? = nil, caching: Bool = true) {
        self.client = client
        self.caching = caching
        let view = ShelvesView(genre: genre)
        self.view = view
        let shelves = Self.cache(for: view, caching: caching)?.read() ?? LibraryShelves()
        self.shelves = shelves
        formats = shelves.formats
        subgenres = shelves.subgenres
    }

    private let client: LibraryClient
    private let caching: Bool

    private(set) var shelves: LibraryShelves
    /// The format and subgenre pills chosen; the genre never changes.
    private(set) var view: ShelvesView
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    /// The pills offered, kept from the view without a pill: choosing one must
    /// not take the others away.
    private(set) var formats: [BookFormat] = []
    private(set) var subgenres: [String] = []

    /// The server has answered once: coming back to the tab asks nothing.
    private var loaded = false
    private var generation = 0

    private func cache(for view: ShelvesView) -> SnapshotCache<LibraryShelves>? {
        Self.cache(for: view, caching: caching)
    }

    private static func cache(for view: ShelvesView, caching: Bool) -> SnapshotCache<LibraryShelves>? {
        guard caching else { return nil }
        return SnapshotCache("library-shelves-\(view.cacheKey)", version: 1)
    }

    /// A format pill; nil is "Tout".
    func select(format: BookFormat?) async {
        guard view.format != format else { return }
        view.format = format
        await switchView()
    }

    /// A subgenre pill of the genre page; nil is "Tout".
    func select(subgenre: String?) async {
        guard view.subgenre != subgenre else { return }
        view.subgenre = subgenre
        await switchView()
    }

    private func switchView() async {
        if let snapshot = cache(for: view)?.read() { withAnimation(.smooth) { shelves = snapshot } }
        await load()
    }

    func loadOnAppear() async {
        guard !loaded, !isLoading else { return }
        await load()
    }

    /// Loads the view. A failure over rails already on screen says nothing:
    /// they stay as they were, and a pull tries again.
    func load() async {
        generation += 1
        let requested = generation
        let asked = view
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await client.shelves(asked)
            guard requested == generation else { return }
            withAnimation(shelves.isEmpty ? nil : .smooth) {
                shelves = fetched
                if asked.format == nil { formats = fetched.formats }
                if asked.subgenre == nil { subgenres = fetched.subgenres }
                // A pill chosen on a launch whose first answer was narrowed
                // still offers what the server says the library holds.
                if formats.isEmpty { formats = fetched.formats }
                if subgenres.isEmpty { subgenres = fetched.subgenres }
            }
            loaded = true
            CoverImages.prefetch(
                (fetched.recent + fetched.toRead + fetched.readRecently + fetched.favorites)
                    .compactMap(\.coverURL)
            )
            if let cache = cache(for: asked) {
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
