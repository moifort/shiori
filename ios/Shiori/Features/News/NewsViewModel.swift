import Foundation
import Observation
import SwiftUI

/// The Actualités tab's state: the friends' moves page by page and the
/// releases the one feed and "À venir" are laid from, the pill and the friend
/// that narrow them. The tab opens on what it last showed: a `SnapshotCache`
/// hands it back from disk before a byte is asked of the network, and the
/// answer slides in over it.
@MainActor @Observable
final class NewsViewModel {
    /// The page size of the feed: a few screens of rows.
    static let pageSize = 20

    private let client: NewsClient
    private let defaults: UserDefaults?
    private var generation = 0

    private(set) var events: [FeedEvent] = []
    /// Another page of moves exists on the server.
    private var moreOnServer = false
    private var cursor: String?
    private(set) var releases: [UpcomingRelease] = []
    private(set) var yearReleases: [UpcomingRelease] = []
    /// The wish list rail, in the server's order.
    private(set) var wishlistReleases: [UpcomingRelease] = []
    private(set) var narratorNews: [NarratorNews] = []
    /// The prizes' winners and the month's discoveries, for Découvrir's
    /// "Prix littéraires" and "Sorties et découvertes".
    private(set) var awardSections: [AwardSection] = []
    private(set) var suggestions: [Suggestion] = []
    /// Discoveries and winners turned down: gone from the page at once.
    private(set) var dismissed: Set<String> = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasLoaded = false
    private(set) var errorMessage: String?
    private(set) var pageFailed = false
    /// Books the reader just took, greyed out at once: a friend's by its book
    /// id, a release by its row id.
    private(set) var taken: Set<String> = []
    /// Rows whose book the reader just wished for or awaited, by the same
    /// keys, and the awaited editions just taken off the wish list.
    private(set) var wished = NewsWishes()
    /// The wish each key's book became, so a second tap takes it back.
    private var wishIds: [String: String] = [:]
    /// The book a card's "+ Ajouter" put on the shelf, and the edition it
    /// awaited, by the card's key: its capsule pressed takes them back.
    private var bookIds: [String: String] = [:]
    private var editionIds: [String: String] = [:]
    private(set) var awaited: Set<String> = []
    private(set) var alertsSilenced = false
    private(set) var isInviting = false
    /// The invitation to pass on, presented the moment it comes back.
    var invitation: FriendInvitation?

    /// The pill chosen; nil is "Tout".
    var format: BookFormat?
    /// The friend picked among the stories; nil is everyone.
    var friendId: String?
    /// When the reader last opened Actualités: the lit rings count from it.
    private(set) var friendsSeenAt: Date?
    /// The rings stay as they were when the tab opened, rather than going out
    /// under the reader's eyes.
    private var ringsSeenAt: Date?

    private static let friendsSeenKey = "news.friendsSeenAt"

    /// What the tab opens on: the feed's first page and everything around it.
    private struct Snapshot: Codable {
        let events: [FeedEvent]
        let releases: [UpcomingRelease]
        let yearReleases: [UpcomingRelease]
        let narratorNews: [NarratorNews]
        var awardSections: [AwardSection] = []
        var suggestions: [Suggestion] = []
        var wishlistReleases: [UpcomingRelease] = []
    }

    /// The last news on disk. Bump the version whenever one of these types
    /// changes shape.
    private let cache: SnapshotCache<Snapshot>?

    /// - Parameter caching: off in tests, which must neither read nor leave
    ///   a snapshot on disk, nor the day Amis was last opened.
    init(client: NewsClient, caching: Bool = true) {
        self.client = client
        defaults = caching ? .standard : nil
        cache = caching ? SnapshotCache<Snapshot>("news", version: 5) : nil
        friendsSeenAt = defaults?.object(forKey: Self.friendsSeenKey) as? Date
        ringsSeenAt = friendsSeenAt
        if let snapshot = cache?.read() {
            events = snapshot.events
            releases = snapshot.releases
            yearReleases = snapshot.yearReleases
            narratorNews = snapshot.narratorNews
            awardSections = snapshot.awardSections
            suggestions = snapshot.suggestions
            wishlistReleases = snapshot.wishlistReleases
        }
    }

    /// The Découvrir page: the week's agenda, what each day brought, the days
    /// to come.
    func agenda(now: Date = .now) -> NewsAgenda {
        NewsAgenda(
            released: NewsFeedLayout.released(releases: yearReleases, narrator: narratorNews, format: nil, now: now),
            events: shownEvents,
            upcoming: calendar(now: now).dated,
            announced: releases,
            wishlist: wishlistReleases,
            suggestions: suggestions,
            awards: awardSections,
            dismissed: dismissed,
            now: now
        )
    }

    // MARK: - Reading

    /// Every move, the books just taken marked as held.
    var shownEvents: [FeedEvent] {
        events.map { event in
            var shown = event
            if taken.contains(event.bookId) { shown.inLibrary = true }
            return shown
        }
    }

    func released(now: Date = .now) -> [ReleasedItem] {
        NewsFeedLayout.released(releases: yearReleases, narrator: narratorNews, format: format, now: now)
    }

    /// The one feed: releases and friends' moves of the last thirty days.
    func feedSections(now: Date = .now) -> [NewsFeedSection] {
        NewsFeedLayout.feedSections(
            released: released(now: now), events: shownEvents, format: format, friendId: friendId, now: now
        )
    }

    /// The pills over the feed: the formats its unnarrowed lines are in.
    func pillFormats(now: Date = .now) -> [BookFormat] {
        let everything = NewsFeedLayout.feedSections(
            released: NewsFeedLayout.released(releases: yearReleases, narrator: narratorNews, format: nil, now: now),
            events: shownEvents, format: nil, friendId: friendId, now: now
        )
        return NewsFeedLayout.pillFormats(in: everything, selected: format)
    }

    /// Everything announced, whatever the pill: the rail sits above the pills,
    /// and the full list has its own.
    func calendar(now: Date = .now) -> ReleaseCalendar {
        ReleaseCalendar(releases: releases, now: now)
    }

    /// More moves to fetch while the oldest loaded still falls in the feed's
    /// thirty days.
    var hasMore: Bool {
        guard moreOnServer, let oldest = events.map(\.at).min() else { return false }
        let since = Calendar.current.date(byAdding: .day, value: -NewsFeedLayout.releasedDays, to: .now) ?? .now
        return oldest >= since
    }

    var stories: [FriendStory] {
        NewsFeedLayout.stories(events: events, seenAt: ringsSeenAt)
    }

    // MARK: - Loading

    /// Each visit lights the rings of who moved since the last one, and lets
    /// the cards turned down on the last one go.
    func loadOnAppear() async {
        markFriendsSeen()
        if !wished.turnedDown.isEmpty {
            dismissed.formUnion(wished.turnedDown)
            wished.forgetTurnedDown()
        }
        guard !hasLoaded else { return }
        await load()
    }

    /// The first page and the releases, asked together. Over rows already on
    /// screen a failure says nothing.
    func load() async {
        generation += 1
        let token = generation
        isLoading = !hasLoaded
        defer { if token == generation { isLoading = false } }
        let (first, dated, voices, year, winners, discoveries, wishlist) = await fetchOpening()
        guard token == generation else { return }
        // Over news already on screen, what changed slides into place rather
        // than the whole page redrawing at once.
        let isFilled = !events.isEmpty || !releases.isEmpty || !yearReleases.isEmpty
        withAnimation(isFilled ? .smooth : nil) {
            if case let .success(first) = first {
                events = first.items
                cursor = first.endCursor
                moreOnServer = first.hasMore
                errorMessage = nil
            }
            if case let .success(dated) = dated { releases = dated }
            if case let .success(voices) = voices { narratorNews = voices }
            if case let .success(year) = year { yearReleases = year }
            if case let .success(winners) = winners { awardSections = winners }
            if case let .success(discoveries) = discoveries { suggestions = discoveries }
            if case let .success(wishlist) = wishlist { wishlistReleases = wishlist }
        }
        if case let .failure(error) = winners, !isCancellation(error) { reportError(error) }
        if case let .failure(error) = discoveries, !isCancellation(error) { reportError(error) }
        if case let .failure(error) = first, !isCancellation(error) {
            if events.isEmpty { errorMessage = error.localizedDescription }
            reportError(error)
        }
        if case let .failure(error) = dated, !isCancellation(error) { reportError(error) }
        if case let .failure(error) = year, !isCancellation(error) { reportError(error) }
        if case let .failure(error) = wishlist, !isCancellation(error) { reportError(error) }
        hasLoaded = true
        if case .success = first { saveSnapshot() }
        await loadAlerts()
    }

    func loadMore() async {
        guard hasMore, !isLoadingMore, let cursor else { return }
        isLoadingMore = true
        pageFailed = false
        let token = generation
        defer { isLoadingMore = false }
        do {
            let page = try await client.feed(cursor, Self.pageSize)
            guard token == generation else { return }
            let known = Set(events.map(\.id))
            events += page.items.filter { !known.contains($0.id) }
            self.cursor = page.endCursor
            moreOnServer = page.hasMore
        } catch {
            guard !isCancellation(error) else { return }
            pageFailed = true
            reportError(error)
        }
    }

    /// Reached a row near the end of what is loaded.
    func prefetchIfNeeded(for id: String) async {
        let ids = events.map(\.id)
        guard let index = ids.firstIndex(of: id), index >= ids.count - 8 else { return }
        await loadMore()
    }

    // MARK: - Actions

    func loadAlerts() async {
        alertsSilenced = await client.alertsSilenced()
    }

    /// The rings keep what they showed until the next visit.
    private func markFriendsSeen(now: Date = .now) {
        ringsSeenAt = friendsSeenAt
        friendsSeenAt = now
        defaults?.set(now, forKey: Self.friendsSeenKey)
    }

    // A friend's book, from the "…" of its row.

    func add(_ event: FeedEvent, _ status: CopiedStatus, as format: BookFormat) async {
        if await perform({ _ = try await client.addFriendBook(event.friendId, event.bookId, status, format) }) {
            taken.insert(event.bookId)
            wished.take(event.bookId)
        }
    }

    func wish(_ event: FeedEvent) async {
        await wish(key: event.bookId) { try await $0.wishFriendBook(event.friendId, event.bookId) }
    }

    /// Shown awaited at once: the server looks the edition up on the web behind.
    func awaitEdition(_ event: FeedEvent, _ format: ReleaseFormat) async {
        awaited.insert(event.bookId)
        if !(await perform({ _ = try await client.awaitFriendBook(event.friendId, event.bookId, format) })) {
            awaited.remove(event.bookId)
        }
    }

    // A book out lately, from the "…" of its row in "Sorti".

    func add(_ item: ReleasedItem, _ status: CopiedStatus, as format: BookFormat) async {
        var draft = item.draft
        draft.format = format
        draft.media = format == .audiobook ? [] : [.print]
        draft.status = status == .read ? .read : .toRead
        if await perform({ _ = try await client.addReleased(draft) }) {
            taken.insert(item.id)
            wished.take(item.id)
        }
    }

    func wish(_ item: ReleasedItem) async {
        await wish(key: item.id) { try await $0.wishReleased(item.draft) }
    }

    /// Shown wished at once, as the button's check answers the tap; back if
    /// the server refused. The wish's id is kept for a second tap.
    private func wish(key: String, _ write: @escaping (NewsClient) async throws -> String) async {
        wished.insert(key)
        let client = client
        var wishId: String?
        if await perform({ wishId = try await write(client) }) {
            wishIds[key] = wishId
        } else {
            wished.remove(key)
        }
    }

    func awaitEdition(_ item: ReleasedItem, _ format: ReleaseFormat) async {
        awaited.insert(item.id)
        if !(await perform({ _ = try await client.awaitReleased(item.draft, format) })) {
            awaited.remove(item.id)
        }
    }

    // A card of Découvrir, from its "+" or its thumb.

    /// "+": the book onto the wish list, whatever brought it.
    func wish(_ card: NewsCard) async {
        switch card {
        case let .friend(move): await wish(move.lead)
        case let .released(item): await wish(item)
        case let .upcoming(release):
            let draft = ReleasedItem.release(release, day: .now).draft
            await wish(key: card.key) { try await $0.wishReleased(draft) }
        case let .suggestion(suggestion):
            var draft = suggestion.draft
            draft.coverURL = suggestion.coverURL
            await wish(key: card.key) { [draft] in try await $0.wishDiscovery(draft, .discovery) }
        case let .award(winner):
            var draft = winner.draft
            draft.coverURL = winner.coverURL
            await wish(key: card.key) { [draft] in try await $0.wishDiscovery(draft, .award) }
        }
    }

    /// A second tap on the wished "Envies": the wish made here is taken back,
    /// an edition of the wish list's rail stops being awaited — as "Retirer"
    /// does on the wish list. The button turns back at once; back again if
    /// the server refused.
    func unwish(_ card: NewsCard) async {
        let key = card.key
        let client = client
        if let wishId = wishIds[key] {
            wished.remove(key)
            if await perform({ try await client.removeWish(wishId) }) {
                wishIds[key] = nil
            } else {
                wished.insert(key)
            }
        } else if let editionId = card.awaitedEditionId {
            wished.drop(key)
            if !(await perform({ try await client.stopAwaiting(editionId) })) {
                wished.restore(key)
            }
        }
    }

    /// "Pas intéressé" from a card's eye: black and white at once, back in
    /// colour if the server refused. It leaves the page once the reader comes
    /// back to it (`loadOnAppear`).
    func dismiss(_ card: NewsCard) async {
        let client = client
        let write: () async throws -> Void
        switch card {
        case let .suggestion(suggestion):
            write = { try await client.dismissSuggestion(suggestion.id) }
        case let .award(winner):
            guard let key = winner.key else { return }
            write = { try await client.dismissWinner(key) }
        default:
            return
        }
        withAnimation(.smooth) { wished.turnDown(card.key) }
        if !(await perform(write)) {
            withAnimation(.smooth) { wished.reconsider(card.key) }
        }
    }

    /// The eye pressed again, or the greyed "+ Ajouter": the book interests
    /// the reader after all, back in colour and kept.
    func reconsider(_ card: NewsCard) async {
        let client = client
        let write: () async throws -> Void
        switch card {
        case let .suggestion(suggestion):
            write = { try await client.reconsiderSuggestion(suggestion.id) }
        case let .award(winner):
            guard let key = winner.key else { return }
            write = { try await client.reconsiderWinner(key) }
        default:
            return
        }
        withAnimation(.smooth) { wished.reconsider(card.key) }
        if !(await perform(write)) {
            withAnimation(.smooth) { wished.turnDown(card.key) }
        }
    }

    /// The "+ Ajouter" of a large card: onto the pile or among the books
    /// read, in the format chosen, whatever brought the book. Its capsule
    /// then says it.
    func add(_ card: NewsCard, _ status: CopiedStatus, as format: BookFormat) async {
        let client = client
        let add: () async throws -> String
        switch card {
        case let .friend(move):
            let event = move.lead
            add = { try await client.addFriendBook(event.friendId, event.bookId, status, format) }
        case let .released(item):
            let draft = item.draft.taken(as: format, status == .read ? .read : .toRead)
            add = { try await client.addReleased(draft) }
        case let .upcoming(release):
            let draft = ReleasedItem.release(release, day: .now).draft.taken(as: format, status == .read ? .read : .toRead)
            add = { try await client.addReleased(draft) }
        case let .suggestion(suggestion):
            var draft = suggestion.draft
            draft.coverURL = suggestion.coverURL
            let taken = draft.taken(as: format, status == .read ? .read : .toRead)
            add = { try await client.addReleased(taken) }
        case let .award(winner):
            var draft = winner.draft
            draft.coverURL = winner.coverURL
            let taken = draft.taken(as: format, status == .read ? .read : .toRead)
            add = { try await client.addReleased(taken) }
        }
        var bookId: String?
        if await perform({ bookId = try await add() }) {
            bookIds[card.key] = bookId
            let isAudio = format == .audiobook
            withAnimation(.snappy) {
                wished.did(status == .read ? .read(isAudio: isAudio) : .toRead(isAudio: isAudio), card.key)
            }
        }
    }

    /// The "+ Ajouter" of a large card: an edition in the phone's language
    /// awaited. Its capsule then says which.
    func awaitEdition(_ card: NewsCard, _ format: ReleaseFormat) async {
        let client = client
        let write: () async throws -> String
        switch card {
        case let .friend(move):
            let event = move.lead
            write = { try await client.awaitFriendBook(event.friendId, event.bookId, format) }
        case let .released(item):
            let draft = item.draft
            write = { try await client.awaitReleased(draft, format) }
        case let .upcoming(release):
            let draft = ReleasedItem.release(release, day: .now).draft
            write = { try await client.awaitReleased(draft, format) }
        case let .suggestion(suggestion):
            let draft = suggestion.draft
            write = { try await client.awaitReleased(draft, format) }
        case let .award(winner):
            let draft = winner.draft
            write = { try await client.awaitReleased(draft, format) }
        }
        var editionId: String?
        if await perform({ editionId = try await write() }) {
            editionIds[card.key] = editionId
            withAnimation(.snappy) { wished.did(.awaited(format), card.key) }
        }
    }

    /// A card's capsule pressed: what its "+ Ajouter" did is taken back, and
    /// "+ Ajouter" comes back.
    func undo(_ card: NewsCard, isWished: Bool) async {
        let key = card.key
        switch wished.state(of: card, isWished: isWished) {
        case .wished:
            await unwish(card)
        case .toRead, .read:
            guard let bookId = bookIds[key] else { return }
            let client = client
            if await perform({ try await client.deleteBook(bookId) }) {
                bookIds[key] = nil
                withAnimation(.snappy) { wished.did(nil, key) }
            }
        case .awaited:
            guard let editionId = editionIds[key] else { return }
            let client = client
            if await perform({ try await client.stopAwaiting(editionId) }) {
                editionIds[key] = nil
                withAnimation(.snappy) { wished.did(nil, key) }
            }
        case .owned, nil:
            return
        }
    }

    /// Runs a write, reporting a failure. True once it went through.
    private func perform(_ write: () async throws -> Void) async -> Bool {
        do {
            try await write()
            return true
        } catch {
            if !isCancellation(error) { reportError(error) }
            return false
        }
    }

    func invite() async {
        isInviting = true
        defer { isInviting = false }
        do {
            invitation = try await client.invite()
        } catch {
            guard !isCancellation(error) else { return }
            reportError(error)
        }
    }

    /// Written off the main actor, the feed's first page at most.
    private func saveSnapshot() {
        guard let cache else { return }
        let snapshot = Snapshot(
            events: Array(events.prefix(Self.pageSize)),
            releases: releases,
            yearReleases: yearReleases,
            narratorNews: narratorNews,
            awardSections: awardSections,
            suggestions: suggestions,
            wishlistReleases: wishlistReleases
        )
        Task.detached { cache.write(snapshot) }
    }

    /// Every section of the opening, each told apart as answered or failed.
    private typealias Opening = (
        feed: Result<CursorPage<FeedEvent>, Error>,
        upcoming: Result<[UpcomingRelease], Error>,
        narratorNews: Result<[NarratorNews], Error>,
        yearReleases: Result<[UpcomingRelease], Error>,
        awards: Result<[AwardSection], Error>,
        discoveries: Result<[Suggestion], Error>,
        wishlist: Result<[UpcomingRelease], Error>
    )

    /// The opening in one request, which reads the library once for every
    /// section. Should a field come back in error, each section is asked
    /// alone, as before: the one that fails keeps what it last showed.
    private func fetchOpening() async -> Opening {
        let client = client
        if let opening = client.opening {
            switch await capture({ try await opening(Self.pageSize) }) {
            case let .success(found):
                return (
                    .success(found.feed), .success(found.upcoming), .success(found.narratorNews),
                    .success(found.yearReleases), .success(found.awards), .success(found.discoveries),
                    .success(found.wishlistReleases)
                )
            case let .failure(error) where !GraphQLHelpers.answeredWithErrors(error):
                return (
                    .failure(error), .failure(error), .failure(error), .failure(error), .failure(error), .failure(error),
                    .failure(error)
                )
            case .failure:
                break
            }
        }
        async let page = capture { try await client.feed(nil, Self.pageSize) }
        async let upcoming = capture { try await client.upcoming() }
        async let narrated = capture { try await client.narratorNews() }
        async let released = capture { try await client.yearReleases() }
        async let prizes = capture { try await client.awards() }
        async let picks = capture { try await client.discoveries() }
        async let wishlist = capture { try await client.wishlistReleases() }
        return await (page, upcoming, narrated, released, prizes, picks, wishlist)
    }

    private func capture<T: Sendable>(_ work: @Sendable () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
