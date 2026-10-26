import Foundation

enum SeriesAPI {
    /// How long the app waits for a saga's catalogue. A saga nobody has
    /// described yet — one an Audible import named — is catalogued by the server
    /// on this first opening, with one web-grounded model call that a cold
    /// function can stretch well past the session's 60 s; every later opening
    /// reads the stored catalogue and answers at once.
    static let firstOpeningTimeout: TimeInterval = 120

    /// Everything the saga screen draws, in one request: the catalogue, the
    /// reader's opinion, and the volumes they hold.
    ///
    /// The catalogue is nil only when the server could not build it — the
    /// catalogue call failed, or the model found no volumes; the next opening
    /// tries again. The opinion is nil until the reader says something about the
    /// saga. `id` is the edition the reader opened, as the server handed it
    /// out: a catalogue built on this opening titles its volumes as that
    /// edition does, and only that edition's volumes come back as owned.
    static func screen(
        id: String,
        proposal: SeriesProposal? = nil
    ) async throws -> (series: BookSeries?, opinion: SeriesOpinion?, owned: [Book]) {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.seriesScreen(id: id)
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesScreenQuery(
                id: id,
                proposed: proposal.map {
                    .some(ShioriGraphQL.ProposedSagaInput(author: $0.author, name: $0.name))
                } ?? .none
            ),
            requestTimeout: firstOpeningTimeout
        )
        return (
            series: data.series.map { BookSeries(catalogue: $0.fragments.seriesCatalogue) },
            opinion: data.seriesOpinion?.fragments.seriesOpinionFields.asOpinion,
            owned: data.mySeriesVolumes.map { row in
                var book = row.fragments.bookSummary.asBook
                book.authorKeys = row.authorKeys
                book.publisher = row.publisher
                book.pageCount = row.pageCount
                book.durationMinutes = row.durationMinutes
                book.addedAt = GraphQLHelpers.parseISO8601(row.addedAt)
                book.startedAt = row.startedAt.flatMap(GraphQLHelpers.parseISO8601)
                book.finishedAt = row.finishedAt.flatMap(GraphQLHelpers.parseISO8601)
                return book
            }
        )
    }

    /// The catalogue of a saga the screen found awaiting one, built by the AI
    /// on this call. Nil when the model found nothing to say.
    static func catalogue(
        id: String,
        proposal: SeriesProposal? = nil
    ) async throws -> BookSeries? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesCatalogueBuiltQuery(
                id: id,
                proposed: proposal.map {
                    .some(ShioriGraphQL.ProposedSagaInput(author: $0.author, name: $0.name))
                } ?? .none
            ),
            requestTimeout: firstOpeningTimeout
        )
        return data.series.map { BookSeries(catalogue: $0.fragments.seriesCatalogue) }
    }

    /// Adds a volume of a saga heard as Audible describes it, through the
    /// reader's account, filed under the saga at its number in the edition
    /// `seriesId` names, on the pile. Throws `NOT_FOUND` when Audible sells no
    /// recording of it and `AUDIBLE_NOT_CONNECTED` without an account.
    static func addAudibleVolume(seriesId: String, volume: Int) async throws -> Book {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.AddAudibleSeriesVolumeMutation(seriesId: seriesId, volume: volume)
        )
        return data.addAudibleSeriesVolume.fragments.bookDetail.asBook
    }

    /// One page of the sagas the reader follows, newest first: the series
    /// screen reads them all and narrows them on the phone.
    static func mySeriesPage(limit: Int, after: String?) async throws -> CursorPage<FollowedSeries> {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.seriesPage(limit: limit, after: after, mode: .all, state: nil)
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MySeriesPageQuery(
                limit: .some(Int32(limit)),
                after: after.map { .some($0) } ?? .none
            )
        )
        return CursorPage(
            items: data.mySeriesPage.items.map { item in
                followedRow(
                    item.fragments.followedSeriesRow,
                    volumes: item.volumes.map(\.fragments.followedVolume),
                    catalogue: item.catalogue?.fragments.catalogueSpine,
                    nextRelease: item.nextRelease?.fragments.discoveredVolumeFields
                )
            },
            hasMore: data.mySeriesPage.hasMore,
            endCursor: data.mySeriesPage.endCursor
        )
    }

    /// One row of the tab, drawn as a page draws it: what the list asks again
    /// for the saga the reader just changed. Nil when they no longer hold a
    /// volume of that edition.
    static func followedSeries(seriesId: String) async throws -> FollowedSeries? {
        #if DEBUG
        if Showcase.isOn {
            return Showcase.followedSeries(seriesId: seriesId)
        }
        #endif
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyFollowedSeriesQuery(seriesId: seriesId)
        )
        return data.myFollowedSeries.map { item in
            followedRow(
                item.fragments.followedSeriesRow,
                volumes: item.volumes.map(\.fragments.followedVolume),
                catalogue: item.catalogue?.fragments.catalogueSpine,
                nextRelease: item.nextRelease?.fragments.discoveredVolumeFields
            )
        }
    }

    /// A row of the Series tab as its fields came back — Découvrir draws its
    /// sagas with the same.
    static func followedRow(
        _ row: ShioriGraphQL.FollowedSeriesRow,
        volumes: [ShioriGraphQL.FollowedVolume],
        catalogue: ShioriGraphQL.CatalogueSpine?,
        nextRelease: ShioriGraphQL.DiscoveredVolumeFields? = nil
    ) -> FollowedSeries {
        var followed = FollowedSeries(row: row)
        followed.announced = nextRelease.map(DiscoveredVolume.init(fields:))
        followed.volumes = volumes.map(\.asBook)
        followed.isCatalogued = catalogue != nil
        followed.strip = SeriesStripItem.strip(
            owned: followed.volumes,
            spine: catalogue?.spine.map(\.fragments.volumeEntry.asVolume) ?? [],
            currentYear: Calendar.current.component(.year, from: .now),
            language: followed.language,
            catalogedAt: catalogue.flatMap { GraphQLHelpers.parseISO8601($0.catalogedAt) }
        )
        return followed
    }

    static func graphQLState(_ state: SeriesState) -> ShioriGraphQL.SeriesState {
        switch state {
        case .notStarted: .notStarted
        case .inProgress: .inProgress
        case .complete: .complete
        case .unfollowed: .unfollowed
        }
    }

    /// Removes one edition of a saga from the library: every volume the reader
    /// holds of the edition `seriesId` names. The rating and heart go with the
    /// saga's last volume. Answers how many books went.
    @discardableResult
    static func delete(seriesId: String) async throws -> Int {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.DeleteSeriesMutation(seriesId: seriesId)
        )
        return data.deleteSeries
    }

    /// Every saga the reader holds, one row per edition, alphabetically: what
    /// a duplicate can be folded into.
    static func mergeCandidates() async throws -> [FollowedSeries] {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MergeCandidatesQuery()
        )
        return data.mySeries.map { FollowedSeries(row: $0.fragments.followedSeriesRow) }
    }

    /// Folds a duplicate saga into the one the reader keeps: the volumes of
    /// the edition `seriesId` names move there at their numbers, and the
    /// duplicate leaves the library with its rating. Two sagas change, so every
    /// list reloads. Answers how many books moved.
    @discardableResult
    static func merge(seriesId: String, into targetId: String) async throws -> Int {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.MergeSeriesMutation(seriesId: seriesId, intoSeriesId: targetId)
        )
        return data.mergeSeries
    }

    /// Rate the saga itself. Leaves every volume rating alone — the two say
    /// different things about different objects.
    static func rate(seriesId: String, stars: Double) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.RateSeriesMutation(seriesId: seriesId, rating: stars)
        )
        return data.rateSeries.fragments.seriesOpinionFields.asOpinion
    }

    static func removeRating(seriesId: String) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.RemoveSeriesRatingMutation(seriesId: seriesId)
        )
        return data.removeSeriesRating.fragments.seriesOpinionFields.asOpinion
    }

    /// Says how many volumes the saga has, for a saga nobody has catalogued:
    /// the next opening draws a provisional catalogue from the count. Kept on
    /// the reader's own opinion, never written into the shared catalogue.
    static func declareVolumeCount(seriesId: String, count: Int) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.DeclareSeriesVolumeCountMutation(seriesId: seriesId, count: count)
        )
        return data.declareSeriesVolumeCount.fragments.seriesOpinionFields.asOpinion
    }

    /// Sets the edition `seriesId` names aside, or follows it again: setting
    /// the English Dune aside leaves the French one followed. Only the saga:
    /// its volumes keep their own statuses.
    static func setFollowed(seriesId: String, followed: Bool) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.SetSeriesFollowedMutation(seriesId: seriesId, followed: followed)
        )
        return data.setSeriesFollowed.fragments.seriesOpinionFields.asOpinion
    }

    static func setFavorite(seriesId: String, favorite: Bool) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.SetSeriesFavoriteMutation(seriesId: seriesId, favorite: favorite)
        )
        return data.setSeriesFavorite.fragments.seriesOpinionFields.asOpinion
    }
}

extension BookSeries {
    init(catalogue: ShioriGraphQL.SeriesCatalogue) {
        self.init(
            id: catalogue.id,
            language: catalogue.language?.asDomain,
            name: catalogue.name,
            author: catalogue.author,
            description: catalogue.description,
            spine: catalogue.spine.map { $0.fragments.volumeEntry.asVolume },
            relatedWorks: catalogue.relatedWorks.map { $0.fragments.volumeEntry.asVolume },
            isProvisional: catalogue.provisional,
            isAwaitingCatalogue: catalogue.awaitingCatalogue,
            isAudio: catalogue.audio,
            catalogedAt: GraphQLHelpers.parseISO8601(catalogue.catalogedAt)
        )
    }
}

private extension FollowedSeries {
    init(row followed: ShioriGraphQL.FollowedSeriesRow) {
        self.init(
            seriesId: followed.id,
            name: followed.name,
            isAudio: followed.audio,
            saga: followed.saga,
            author: followed.author,
            language: followed.language?.asDomain,
            state: followed.state?.asDomain,
            genre: followed.genre?.asDomain,
            ownedCount: followed.ownedCount,
            shelvedAt: GraphQLHelpers.parseISO8601(followed.shelvedAt),
            opinion: followed.opinion?.fragments.seriesOpinionFields.asOpinion
        )
    }
}

extension ShioriGraphQL.FollowedVolume {
    /// Only what a cover in the strip draws: the image, the status pinned on
    /// it, and the title the placeholder is lettered from.
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: [],
            format: format.asDomain,
            language: language?.asDomain,
            series: series.map {
                SeriesMembership(id: "", name: "", volume: $0.volume, kind: $0.kind.asDomain)
            },
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain
        )
    }
}
