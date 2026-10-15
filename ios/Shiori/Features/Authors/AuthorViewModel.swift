import SwiftUI

/// An author's page: who they are, what the reader holds of them and what they
/// could add, and what the author announced lately.
@MainActor
@Observable
final class AuthorViewModel {
    let key: String
    let name: String

    private(set) var page: AuthorPage?
    /// What the author has announced or brought out lately, in each format:
    /// asked beside the page, and left out if it cannot be had.
    private(set) var releases: [ReleaseFormat: AuthorReleases] = [:]
    private(set) var isLoading = true
    var errorMessage: String?
    /// The saga or the work being added, its "+" turning.
    private(set) var adding: String?
    /// The refresh is one grounded model call and takes a while.
    private(set) var isRefreshing = false
    /// The refresh came back with nothing: the page on screen is the old one.
    var refreshFailed = false

    /// Offered by Découvrir as an author a friend loves, whom the reader may
    /// hold nothing of: the page is then built from `name`.
    private let isOffered: Bool
    private let client: AuthorsClient

    init(key: String, name: String, isOffered: Bool, client: AuthorsClient) {
        self.key = key
        self.name = name
        self.isOffered = isOffered
        self.client = client
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        let (client, key) = (client, key)
        async let found = try? client.releases(key)
        do {
            let fresh = try await client.page(key, isOffered ? name : nil)
            let foundReleases = await found
            withAnimation(page == nil ? nil : .smooth) {
                page = fresh
                if let foundReleases { releases = foundReleases }
            }
            if fresh == nil { errorMessage = nil }
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// Asks the world about the author again. The page is read afresh when the
    /// catalogue was rebuilt; otherwise the reader is told the old one stands.
    func refreshCatalogue() async {
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            if try await client.refresh(key) {
                await load()
            } else {
                refreshFailed = true
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Gives up an edition awaited: gone from the page at once, and read
    /// again if the server refused.
    func stopAwaiting(_ edition: AwaitedEdition) async {
        for format in releases.keys {
            withAnimation(.smooth) { releases[format]?.awaited.removeAll { $0.id == edition.id } }
        }
        do {
            try await client.stopAwaiting(edition.id)
        } catch {
            errorMessage = reportError(error)
            await load()
        }
    }

    /// A saga is started with its first volume, filed into the saga so it joins
    /// the Series tab and the saga screen at once.
    func start(_ saga: AuthorSeries, author: String, format: AuthorShelfFormat) async {
        adding = saga.id
        defer { adding = nil }
        await add(
            title: saga.firstVolumeTitle ?? saga.name,
            author: author,
            series: SeriesMembership(id: saga.id, name: saga.name, volume: 1, kind: .main),
            format: format
        )
    }

    func add(_ work: AuthorWork, author: String, format: AuthorShelfFormat) async {
        adding = work.id
        defer { adding = nil }
        await add(title: work.title, author: author, series: nil, format: format)
    }

    /// Onto the pile, as the saga screen adds a missing volume: a title lookup
    /// first for the cover and the details, the author, the saga and the format
    /// of the page kept whatever the lookup answered.
    private func add(title: String, author: String, series: SeriesMembership?, format: AuthorShelfFormat) async {
        var draft = BookDraft(title: title, authors: [author], format: format.bookFormat)
        draft.series = series
        draft.status = .toRead
        do {
            _ = try await client.addBook(draft, .title("\(title) — \(author)"))
            await load()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
