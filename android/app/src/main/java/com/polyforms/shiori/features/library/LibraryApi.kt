package com.polyforms.shiori.features.library

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.features.discover.AwardMention
import com.polyforms.shiori.features.discover.LiteraryAward
import com.polyforms.shiori.features.narrators.NarratorRow
import com.polyforms.shiori.features.series.SeriesApi
import com.polyforms.shiori.graphql.LibraryPageQuery
import com.polyforms.shiori.graphql.LibraryShelvesQuery
import com.polyforms.shiori.graphql.LovedSeriesQuery
import com.polyforms.shiori.graphql.PileQuery
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.parseISO8601

object LibraryApi {
    suspend fun shelves(view: ShelvesView): LibraryShelves {
        if (Showcase.isOn) return LibraryShelves()
        val s = GraphQLClient.fetch(
            LibraryShelvesQuery(Optional.presentIfNotNull(view.format?.graphQL), Optional.presentIfNotNull(view.genre?.graphQL), Optional.presentIfNotNull(view.subgenre)),
        ).libraryShelves
        return LibraryShelves(
            formats = s.formats.map { it.asDomain },
            recent = s.recent.map { it.bookSummary.asBook },
            toRead = s.toRead.map { it.bookSummary.asBook },
            readRecently = s.readRecently.map { it.bookSummary.asBook },
            favorites = s.favorites.map { it.bookSummary.asBook },
            genres = s.genres.map { GenreShelf(it.genre.asDomain, it.count, it.cover?.coverUrl) },
            subgenres = s.subgenres,
            series = s.series.map { SeriesApi.followedRow(it.followedSeriesRow, it.volumes.map { v -> v.followedVolume }, it.catalogue?.catalogueSpine) },
            authors = s.authors.map {
                FollowedAuthor(it.key, it.name, it.indexLetter, it.portraitUrl, it.bookCount, it.seriesCount, it.favoriteCount, it.averageRating, parseISO8601(it.shelvedAt), emptyList(), it.favorite)
            },
            narrators = s.narrators.map { NarratorRow(it.key, it.name, it.portraitUrl) },
        )
    }

    suspend fun lovedSeries(view: ShelvesView): List<FollowedSeries> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(
            LovedSeriesQuery(Optional.presentIfNotNull(view.format?.graphQL), Optional.presentIfNotNull(view.genre?.graphQL), Optional.presentIfNotNull(view.subgenre)),
        ).libraryShelves.lovedSeries.map { SeriesApi.followedRow(it.followedSeriesRow, it.volumes.map { v -> v.followedVolume }, it.catalogue?.catalogueSpine) }
    }

    suspend fun shelfPage(query: ShelfQuery, limit: Int, after: String?): LibraryPageResult {
        if (Showcase.isOn) return LibraryPageResult(emptyList(), false)
        val view = query.view
        val page = GraphQLClient.fetch(
            LibraryPageQuery(
                favorite = if (query.favorite) Optional.present(true) else Optional.Absent,
                status = Optional.presentIfNotNull(query.serverStatus?.graphQL),
                format = Optional.presentIfNotNull(view.format?.graphQL),
                genre = Optional.presentIfNotNull(view.genre?.graphQL),
                subgenre = Optional.presentIfNotNull(view.subgenre),
                limit = Optional.present(limit),
                after = Optional.presentIfNotNull(after),
            ),
        ).libraryPage
        return LibraryPageResult(page.books.map { it.bookSummary.asBook }, page.hasMore)
    }

    suspend fun pile(view: ShelvesView): Pile {
        if (Showcase.isOn) return Pile()
        val p = GraphQLClient.fetch(
            PileQuery(Optional.presentIfNotNull(view.format?.graphQL), Optional.presentIfNotNull(view.genre?.graphQL), Optional.presentIfNotNull(view.subgenre)),
        ).pile
        val genres = p.genres.map { it.asDomain }.toSet()
        return Pile(
            formats = p.formats.map { it.asDomain },
            genres = BookGenre.alphabetical.filter { it in genres },
            sections = p.sections.mapNotNull { section ->
                val kind = PileSectionKind.entries.firstOrNull { it.graphQLName == section.kind.rawValue } ?: return@mapNotNull null
                PileSection(kind, section.picks.map { pick ->
                    val book = pick.book.bookSummary.asBook.copy(
                        narrators = pick.book.narrators,
                        startedAt = parseISO8601(pick.book.startedAt),
                        recommendation = pick.book.recommendation?.let { BookRecommendation(it.recommenderName) },
                    )
                    PilePick(book, pick.award?.let { m -> LiteraryAward.of(m.award.rawValue)?.let { AwardMention(it, m.year) } })
                })
            },
        )
    }
}
