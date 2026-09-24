import Foundation

enum SeriesAPI {
    /// How long the app waits for a saga's catalogue. A saga nobody has
    /// described yet — one an Audible import named — is catalogued by the server
    /// on this first opening, with one web-grounded model call that a cold
    /// function can stretch well past the session's 60 s; every later opening
    /// reads the stored catalogue and answers at once.
    private static let firstOpeningTimeout: TimeInterval = 120

    /// Everything the saga screen draws, in one request: the catalogue, the
    /// reader's opinion, and the volumes they hold.
    ///
    /// The catalogue is nil only when the server could not build it — the
    /// catalogue call failed, or the model found no volumes; the next opening
    /// tries again. The opinion is nil until the reader says something about the
    /// saga. `language` is the edition the reader opened: a catalogue built on
    /// this opening titles its volumes as that edition does, and only that
    /// edition's volumes come back as owned.
    static func screen(
        id: String,
        language: BookLanguage? = nil
    ) async throws -> (series: BookSeries?, opinion: SeriesOpinion?, owned: [Book]) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.SeriesScreenQuery(id: id, language: graphQLLanguage(language)),
            requestTimeout: firstOpeningTimeout
        )
        return (
            series: data.series.map { BookSeries(catalogue: $0.fragments.seriesCatalogue) },
            opinion: data.seriesOpinion?.fragments.seriesOpinionFields.asOpinion,
            owned: data.mySeriesVolumes.map { $0.fragments.bookSummary.asBook }
        )
    }

    /// Asks the world about the saga again: a fresh catalogue replaces the
    /// stored one, for everyone. Nil when it could not be rebuilt — the model
    /// failed or found nothing — in which case the previous catalogue stands.
    /// One grounded model call, so it waits as long as a first opening does.
    static func refresh(seriesId: String, language: BookLanguage? = nil) async throws -> BookSeries? {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.RefreshSeriesMutation(
                seriesId: seriesId,
                language: graphQLLanguage(language)
            ),
            requestTimeout: firstOpeningTimeout
        )
        return data.refreshSeries.map { BookSeries(catalogue: $0.fragments.seriesCatalogue) }
    }

    private static func graphQLLanguage(
        _ language: BookLanguage?
    ) -> GraphQLNullable<GraphQLEnum<ShioriGraphQL.BookLanguage>> {
        language.map { .some(LibraryAPI.graphQLLanguage($0)) } ?? .none
    }

    /// One page of the sagas the reader follows, ordered and narrowed as the
    /// Library tab is: newest first, the hearted sagas only, or the sagas in
    /// one state.
    static func mySeriesPage(
        limit: Int,
        offset: Int,
        mode: LibraryMode = .all,
        state: SeriesState? = nil
    ) async throws -> (items: [FollowedSeries], hasMore: Bool) {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MySeriesPageQuery(
                limit: .some(Int32(limit)),
                offset: .some(Int32(offset)),
                favorite: mode == .favorites ? .some(true) : .none,
                state: state.map { .some(.case(graphQLState($0))) } ?? .none
            )
        )
        return (
            items: data.mySeriesPage.items.map { item in
                followedRow(
                    item.fragments.followedSeriesRow,
                    volumes: item.volumes.map(\.fragments.followedVolume),
                    spine: item.catalogue?.spine.map(\.fragments.volumeEntry)
                )
            },
            hasMore: data.mySeriesPage.hasMore
        )
    }

    /// One row of the tab, drawn as a page draws it: what the list asks again
    /// for the saga the reader just changed. Nil when they no longer hold a
    /// volume of that edition.
    static func followedSeries(seriesId: String, language: BookLanguage?) async throws -> FollowedSeries? {
        let data = try await GraphQLHelpers.fetch(
            GraphQLClient.shared.apollo,
            query: ShioriGraphQL.MyFollowedSeriesQuery(
                seriesId: seriesId, language: graphQLLanguage(language)
            )
        )
        return data.myFollowedSeries.map { item in
            followedRow(
                item.fragments.followedSeriesRow,
                volumes: item.volumes.map(\.fragments.followedVolume),
                spine: item.catalogue?.spine.map(\.fragments.volumeEntry)
            )
        }
    }

    /// A row of the Series tab as its fields came back — Découvrir draws its
    /// sagas with the same.
    static func followedRow(
        _ row: ShioriGraphQL.FollowedSeriesRow,
        volumes: [ShioriGraphQL.FollowedVolume],
        spine: [ShioriGraphQL.VolumeEntry]?
    ) -> FollowedSeries {
        var followed = FollowedSeries(row: row)
        followed.volumes = volumes.map(\.asBook)
        followed.strip = SeriesStripItem.strip(
            owned: followed.volumes,
            spine: spine?.map(\.asVolume) ?? [],
            currentYear: Calendar.current.component(.year, from: .now),
            language: followed.language
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

    /// Removes the saga from the library: every volume the reader holds, or
    /// only the volumes of `language` when they stand in one edition of a saga
    /// held in two. The rating and heart go with the last volume. Answers how
    /// many books went.
    @discardableResult
    static func delete(seriesId: String, language: BookLanguage? = nil) async throws -> Int {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.DeleteSeriesMutation(
                seriesId: seriesId,
                language: graphQLLanguage(language)
            )
        )
        return data.deleteSeries
    }

    /// Rate the saga itself. Leaves every volume rating alone — the two say
    /// different things about different objects.
    static func rate(seriesId: String, stars: Int) async throws -> SeriesOpinion {
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

    /// Sets the saga aside, or follows it again. Only the saga: its volumes
    /// keep their own statuses.
    /// One edition when `language` names it, else the whole saga: setting the
    /// English Dune aside leaves the French one followed.
    static func setFollowed(
        seriesId: String,
        followed: Bool,
        language: BookLanguage? = nil
    ) async throws -> SeriesOpinion {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            concerning: .series(id: seriesId),
            mutation: ShioriGraphQL.SetSeriesFollowedMutation(
                seriesId: seriesId,
                followed: followed,
                language: graphQLLanguage(language)
            )
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

private extension BookSeries {
    init(catalogue: ShioriGraphQL.SeriesCatalogue) {
        self.init(
            id: catalogue.id,
            name: catalogue.name,
            author: catalogue.author,
            description: catalogue.description,
            spine: catalogue.spine.map { $0.fragments.volumeEntry.asVolume },
            relatedWorks: catalogue.relatedWorks.map { $0.fragments.volumeEntry.asVolume },
            isProvisional: catalogue.provisional
        )
    }
}

private extension FollowedSeries {
    init(row followed: ShioriGraphQL.FollowedSeriesRow) {
        self.init(
            seriesId: followed.id,
            name: followed.name,
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

private extension ShioriGraphQL.FollowedVolume {
    /// Only what a cover in the strip draws: the image, the status pinned on
    /// it, and the title the placeholder is lettered from.
    var asBook: Book {
        Book(
            id: id,
            title: title,
            authors: [],
            format: format.asDomain,
            series: series.map {
                SeriesMembership(id: "", name: "", volume: $0.volume, kind: $0.kind.asDomain)
            },
            coverURL: coverUrl.flatMap(URL.init(string:)),
            status: status.asDomain
        )
    }
}
