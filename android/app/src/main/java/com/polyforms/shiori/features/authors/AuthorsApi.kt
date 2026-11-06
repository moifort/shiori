package com.polyforms.shiori.features.authors

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.series.SeriesApi
import com.polyforms.shiori.graphql.AuthorPageQuery
import com.polyforms.shiori.graphql.AuthorPortraitChoicesQuery
import com.polyforms.shiori.graphql.CorrectAuthorMutation
import com.polyforms.shiori.graphql.MyAuthorsPageQuery
import com.polyforms.shiori.graphql.SetAuthorFavoriteMutation
import com.polyforms.shiori.graphql.fragment.AuthorPageFields
import com.polyforms.shiori.graphql.fragment.FollowedAuthorRow
import com.polyforms.shiori.graphql.type.AuthorOrder
import com.polyforms.shiori.graphql.type.PortraitSource
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.parseISO8601

fun <T> Change<T>?.optional(): Optional<T?> = when (this) {
    null -> Optional.Absent
    is Change.Set -> Optional.present(value)
    Change.Clear -> Optional.present(null)
}

val AuthorListOrder.graphQL: AuthorOrder
    get() = when (this) {
        AuthorListOrder.RECENT -> AuthorOrder.RECENT
        AuthorListOrder.NAME -> AuthorOrder.NAME
        AuthorListOrder.LOVED -> AuthorOrder.LOVED
    }

fun PortraitSource.asDomain(): PortraitChoice.Source = when (this) {
    PortraitSource.WIKIPEDIA -> PortraitChoice.Source.WIKIPEDIA
    PortraitSource.WIKIDATA -> PortraitChoice.Source.WIKIDATA
    PortraitSource.OPEN_LIBRARY -> PortraitChoice.Source.OPEN_LIBRARY
    else -> PortraitChoice.Source.WEB
}

object AuthorsApi {
    suspend fun page(key: String, offered: String? = null, waitForCatalogue: Boolean = false): AuthorPage? {
        if (Showcase.isOn) return null
        return GraphQLClient.fetch(AuthorPageQuery(key, Optional.presentIfNotNull(offered), waitForCatalogue)).authorPage?.authorPageFields?.asDomain
    }

    suspend fun correct(key: String, correction: PersonCorrection): AuthorPage =
        GraphQLClient.perform(
            CorrectAuthorMutation(
                key = key,
                nationality = correction.nationality.optional(),
                birthYear = correction.birthYear.optional(),
                deathYear = correction.deathYear.optional(),
                biography = correction.biography.optional(),
                portraitUrl = Optional.presentIfNotNull(correction.portraitURL),
            ),
        ).correctAuthor.authorPageFields.asDomain

    suspend fun portraitChoices(key: String): List<PortraitChoice> =
        GraphQLClient.fetch(AuthorPortraitChoicesQuery(key)).authorPortraitChoices.orEmpty()
            .map { PortraitChoice(it.source.asDomain(), it.url, it.isCurrent) }

    suspend fun setFavorite(key: String, favorite: Boolean): Boolean {
        if (Showcase.isOn) return favorite
        return GraphQLClient.perform(SetAuthorFavoriteMutation(key, favorite)).setAuthorFavorite
    }

    suspend fun myAuthorsPage(limit: Int, after: String?, order: AuthorListOrder): CursorPage<FollowedAuthor> {
        if (Showcase.isOn) return CursorPage(emptyList(), false, null)
        val page = GraphQLClient.fetch(
            MyAuthorsPageQuery(Optional.present(limit), Optional.presentIfNotNull(after), Optional.Absent, Optional.present(order.graphQL)),
        ).myAuthorsPage
        return CursorPage(page.items.map { it.followedAuthorRow.asDomain }, page.hasMore, page.endCursor)
    }
}

val FollowedAuthorRow.asDomain: FollowedAuthor
    get() = FollowedAuthor(
        key = key,
        name = name,
        indexLetter = indexLetter,
        portraitURL = portraitUrl,
        bookCount = bookCount,
        seriesCount = seriesCount,
        favoriteCount = favoriteCount,
        averageRating = averageRating,
        shelvedAt = parseISO8601(shelvedAt),
        books = books.map { it.bookSummary.asBook },
        favorite = favorite,
        surname = surname,
    )

val AuthorPageFields.asDomain: AuthorPage
    get() = AuthorPage(
        author = FollowedAuthor(
            key = author.key,
            name = author.name,
            indexLetter = author.indexLetter,
            portraitURL = author.portraitUrl,
            bookCount = author.bookCount,
            seriesCount = author.seriesCount,
            favoriteCount = author.favoriteCount,
            averageRating = author.averageRating,
            shelvedAt = null,
            books = emptyList(),
            favorite = author.favorite,
        ),
        readCount = author.readCount,
        nationality = catalogue?.nationality,
        birthYear = catalogue?.birthYear,
        deathYear = catalogue?.deathYear,
        biography = catalogue?.biography,
        sagas = sagas.map { SeriesApi.followedRow(it.followedSeriesRow, it.volumes.map { v -> v.followedVolume }, it.catalogue?.catalogueSpine) },
        sagasNotHeld = sagasNotHeld.map {
            val s = it.authorSeriesFields
            AuthorSeries(s.id, s.name, s.audio, s.author, s.volumeCount, s.firstVolumeTitle, s.coverUrl)
        },
        books = books.map { it.bookSummary.asBook },
        booksNotHeld = booksNotHeld.map { AuthorWork(it.title, it.publishedIn, it.coverUrl) },
        isAwaitingCatalogue = awaitingCatalogue,
    )
