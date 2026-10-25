import SwiftUI

/// One saga's screen: its catalogue, the volumes the reader holds — the
/// friend's, on their shelf — what the reader thinks of it, and what Découvrir
/// found of it in the edition opened.
@MainActor
@Observable
final class SeriesViewModel {
    /// The edition opened — the saga in one language — as the server handed
    /// it out. Never built here: the language is read off what it loads.
    let seriesId: String
    /// The friend whose shelf the saga was opened from: where it stands is
    /// theirs, and nothing changes the reader's library.
    let friend: SeriesFriend?

    private(set) var series: BookSeries?
    /// Every volume of the saga the reader holds — the friend, on their
    /// shelf — numbered or not.
    private(set) var owned: [Book] = []
    private(set) var opinion: SeriesOpinion?
    private(set) var isLoading = true
    var errorMessage: String?
    /// The volume being added, its "+" turning.
    private(set) var addingTitle: String?
    /// A rating, a heart or the removal is on its way.
    private(set) var isSaving = false
    /// The AI is building the catalogue of a saga nobody had catalogued: the
    /// volumes held are on screen meanwhile, and every action stays at hand.
    private(set) var isCataloguing = false
    /// The AI is looking for the saga's next volume in an edition nobody
    /// watched yet.
    private(set) var isLookingUpReleases = false
    /// The next volume announced in the edition opened. Last opening's at
    /// once, brought up to date underneath.
    private(set) var releases: SagaReleases?

    private let proposal: SeriesProposal?
    private let client: SeriesClient

    init(
        seriesId: String,
        proposal: SeriesProposal?,
        friend: SeriesFriend?,
        client: SeriesClient
    ) {
        self.seriesId = seriesId
        self.proposal = proposal
        self.friend = friend
        self.client = client
    }

    /// The language of the edition opened, as its catalogue or a volume held
    /// says it; nil until the screen has loaded.
    var language: BookLanguage? { series?.language ?? owned.first?.language }

    var isFavorite: Bool { opinion?.favorite == true }
    var isFollowed: Bool { followedAhead ?? opinion?.follows(language) ?? true }

    /// The bell's state as the reader last set it, drawn before the server
    /// answers so the bell rings without a wait. Cleared once every call made
    /// from it has come back.
    private var followedAhead: Bool?
    private var followCallsInFlight = 0

    /// What the saga is read as: the format of the volumes held — a manga
    /// stays a manga — else a recording for a saga heard, a book otherwise.
    var takenFormat: BookFormat {
        owned.first?.format ?? (series?.isAudio == true ? .audiobook : .book)
    }

    /// The highest number among the volumes the reader holds: where the count
    /// sheet starts, since the saga has at least that many.
    var highestOwnedVolume: Int { owned.compactMap(\.series?.volume).max() ?? 0 }

    /// The volume a saga is started with: the first of the spine already out
    /// in the edition opened.
    var firstVolume: Volume? {
        guard let series else { return nil }
        let year = Calendar.current.component(.year, from: .now)
        let datedUpTo = series.spine.datedUpTo(in: language, catalogedAt: series.catalogedAt)
        return series.spine.first { !$0.isForthcoming(asOf: year, in: language, datedUpTo: datedUpTo) }
    }

    /// What the AI is writing for this screen, said in its bar; nil when
    /// nothing is being written.
    var generating: LocalizedStringKey? {
        if isCataloguing { return "L'IA complète le catalogue" }
        if isLookingUpReleases { return "L'IA cherche les parutions" }
        return nil
    }

    /// The saga's name, from the catalogue or else from a volume held.
    var name: String { series?.name ?? owned.first?.series?.name ?? "" }

    // MARK: - Loading

    /// One request for the whole screen: the catalogue, the opinion and the
    /// volumes held, so the screen draws once rather than filling in.
    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let friend {
            await loadFriendShelf(friend)
            return
        }
        do {
            let screen = try await client.screen(seriesId, proposal)
            series = screen.series
            opinion = screen.opinion
            owned = screen.owned
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Builds the catalogue of a saga the screen found awaiting one: the
    /// volumes held stay on screen while the AI writes it, then it slides in.
    /// Nil from the model leaves the saga uncatalogued, as a first opening that
    /// waited would have.
    func buildCatalogueIfAwaiting() async {
        guard series?.isAwaitingCatalogue == true, !isCataloguing else { return }
        isCataloguing = true
        defer { isCataloguing = false }
        do {
            let built = try await client.catalogue(seriesId, proposal)
            withAnimation(.smooth) { series = built }
        } catch {
            _ = reportError(error)
        }
    }

    /// The catalogue, with the friend's volumes, stars and heart in place of
    /// the reader's own.
    private func loadFriendShelf(_ friend: SeriesFriend) async {
        do {
            let screen = try await client.friendScreen(friend.id, seriesId)
            series = screen.series
            owned = screen.saga?.volumes ?? []
            opinion = screen.saga.map {
                SeriesOpinion(seriesId: seriesId, rating: $0.rating, favorite: $0.favorite)
            }
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// What Découvrir found of the saga, for the edition the reader opened —
    /// looked up on the spot when nobody ever did. Not drawn on a friend's
    /// shelf.
    func loadReleases() async {
        guard friend == nil else { return }
        let key = seriesId
        if releases == nil { releases = SagaReleasesCache.entries[key] }
        do {
            var fetched = try await client.releases(seriesId)
            withAnimation(releases == nil ? nil : .smooth) { releases = fetched }
            // Nobody ever looked the saga up in this edition: it is looked up
            // now, and the section slides in when the web has answered.
            if !fetched.watched {
                isLookingUpReleases = true
                defer { isLookingUpReleases = false }
                fetched = try await client.lookUpReleases(seriesId)
                withAnimation(.smooth) { releases = fetched }
            }
            SagaReleasesCache.entries[key] = fetched
        } catch {
            // A bonus on this screen: the failure is reported, not shown.
            _ = reportError(error)
        }
    }

    // MARK: - The reader's opinion

    // The server answers with the opinion as it now stands, so the screen takes
    // that rather than guessing: a rating taken back may leave a heart behind.

    /// Zero stars takes the rating back.
    func rate(_ stars: Double) async {
        await changeOpinion { [client, seriesId] in
            stars == 0 ? try await client.removeRating(seriesId) : try await client.rate(seriesId, stars)
        }
    }

    /// Only the edition opened: the French row set aside says nothing of the
    /// English one.
    /// Set in the background, no scrim over the page: the bell swings at
    /// once and turns back only if the server refuses.
    func setFollowed(_ followed: Bool) async {
        followedAhead = followed
        followCallsInFlight += 1
        defer {
            followCallsInFlight -= 1
            if followCallsInFlight == 0 { followedAhead = nil }
        }
        do {
            let saved = try await client.setFollowed(seriesId, followed)
            // A later tap's answer is the one that counts.
            if followedAhead == followed { opinion = saved }
        } catch {
            errorMessage = reportError(error)
        }
    }

    func setFavorite(_ favorite: Bool) async {
        await changeOpinion { [client, seriesId] in try await client.setFavorite(seriesId, favorite) }
    }

    private func changeOpinion(_ change: @escaping @Sendable () async throws -> SeriesOpinion) async {
        isSaving = true
        defer { isSaving = false }
        do {
            opinion = try await change()
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// The reader's own count, for a saga nobody catalogued; the provisional
    /// catalogue it gives rise to is read again. Answers the message to show,
    /// or nil once saved.
    func declareVolumeCount(_ count: Int) async -> String? {
        do {
            opinion = try await client.declareVolumeCount(seriesId, count)
            await load()
            return nil
        } catch {
            return reportError(error)
        }
    }

    // MARK: - The saga itself

    /// The edition this screen shows, and no other. True once removed.
    func delete() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            try await client.delete(seriesId)
            return true
        } catch {
            errorMessage = reportError(error)
            return false
        }
    }

    func mergeCandidates() async throws -> [FollowedSeries] {
        try await client.mergeCandidates()
    }

    /// Folds this edition into the saga picked. Answers the message to show,
    /// or nil once merged.
    func merge(into target: FollowedSeries) async -> String? {
        do {
            try await client.merge(seriesId, target.seriesId)
            return nil
        } catch {
            return reportError(error)
        }
    }

    /// The genre corrected on one volume; the server carries it to every
    /// volume, and every volume on screen takes the answer, field by field as
    /// the server does. Answers the message to show, or nil once saved.
    func correctGenre(_ correction: BookCorrection) async -> String? {
        guard let volume = owned.first else { return nil }
        do {
            let updated = try await client.updateBook(volume.id, correction)
            owned = owned.map { book in
                var book = book
                if correction.genre != nil { book.genre = updated.genre }
                if correction.subgenres != nil { book.subgenres = updated.subgenres }
                return book
            }
            return nil
        } catch {
            return reportError(error)
        }
    }

    func subgenres() async -> [String] {
        (try? await client.subgenres()) ?? []
    }

    // MARK: - Adding a volume

    /// Adds a missing volume as a full record, filed under this saga at its
    /// number, so its row turns into the reader's book at once.
    ///
    /// A recording takes Audible's own record of it through the reader's
    /// account. Otherwise — no account, a recording Audible does not sell, a
    /// book — the volume is looked up as the volume it is, which spends a
    /// scan, and added with what the catalogue knows when the lookup cannot run.
    func add(_ volume: Volume, author: String, as format: BookFormat? = nil, status: ReadingStatus = .toRead) async {
        addingTitle = volume.title
        defer { addingTitle = nil }
        let format = format ?? takenFormat
        if format == .audiobook, volume.kind == .main, let number = volume.number,
           let heard = await addHeard(number: number, status: status) {
            owned.append(heard)
            return
        }
        // A saga read on the Kindle goes on being read there.
        let media = owned.first { $0.format != .audiobook }
            .map(\.media).flatMap { $0.isEmpty ? nil : $0 } ?? [.print]
        let membership = SeriesMembership(
            id: seriesId,
            name: series?.name ?? owned.first?.series?.name ?? volume.title,
            volume: volume.number,
            kind: volume.kind
        )
        let edition = language
        var draft = BookDraft(title: volume.title, authors: [author], format: format, media: media)
        // Filed here whatever the lookup answers, in the edition of this row:
        // a volume added without one would open a second row on the Series tab.
        draft.series = membership
        draft.language = edition
        draft.status = status
        // A provisional volume is titled after its saga and has no title to
        // look up: it is added bare, at its number, and described later.
        let lookUp: BookAddition.LookUp? = series?.isProvisional == true
            ? nil
            : .volume(
                title: volume.title,
                author: author,
                membership: membership,
                format: format,
                media: media,
                language: edition
            )
        do {
            owned.append(try await client.addBook(draft, lookUp))
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Audible's record of a volume, moved to the books read when it was
    /// heard already; nil when Audible could not give it, and the volume is
    /// then added as a book is.
    private func addHeard(number: Int, status: ReadingStatus) async -> Book? {
        var heard: Book
        do {
            heard = try await client.addAudibleVolume(seriesId, number)
        } catch {
            let code = (error as? APIError)?.domainCode
            if code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED" { _ = reportError(error) }
            return nil
        }
        track(.bookAdded(source: .series))
        // Failing the move, it stays on the pile rather than being added twice.
        if status != .toRead {
            do {
                heard = try await client.setStatus(heard.id, status)
            } catch {
                errorMessage = reportError(error)
            }
        }
        return heard
    }

    // MARK: - Announced volumes

    /// The page of a volume the release watch announced in the edition opened:
    /// what Découvrir knows of it when it is the next one, else what the
    /// catalogue keeps of the announcement. Nil for a volume the watch never
    /// found in that edition.
    func announcedVolume(_ volume: Volume) -> DiscoveredVolume? {
        guard volume.kind == .main, let number = volume.number,
              let release = language.flatMap({ volume.release(in: $0) })
        else { return nil }
        if let next = releases?.next, next.number == number { return next }
        return DiscoveredVolume(
            number: number,
            title: release.title,
            date: release.date,
            isbn13: nil,
            coverURL: release.coverURL
        )
    }

    /// The saga as the announced volume's page reads it: the edition opened.
    var announcedSaga: SagaDiscovery? {
        guard let series, let language else { return nil }
        let followed = FollowedSeries(
            seriesId: seriesId,
            name: series.name,
            isAudio: series.isAudio,
            author: series.author,
            language: language,
            state: nil,
            genre: owned.first?.genre,
            ownedCount: owned.count
        )
        return SagaDiscovery(series: followed, releases: releases ?? SagaReleases(watched: true, next: nil))
    }
}
