package com.polyforms.shiori.features.narrators

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.authors.AuthorListOrder
import com.polyforms.shiori.features.authors.PersonCorrection
import com.polyforms.shiori.features.authors.PortraitChoice
import com.polyforms.shiori.features.authors.asDomain
import com.polyforms.shiori.features.authors.graphQL
import com.polyforms.shiori.features.authors.optional
import com.polyforms.shiori.features.series.SeriesApi
import com.polyforms.shiori.graphql.CorrectNarratorMutation
import com.polyforms.shiori.graphql.MyNarratorsPageQuery
import com.polyforms.shiori.graphql.NarratorPageQuery
import com.polyforms.shiori.graphql.NarratorPortraitChoicesQuery
import com.polyforms.shiori.graphql.SetNarratorFavoriteMutation
import com.polyforms.shiori.graphql.fragment.NarratorPageFields
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asBook
import com.polyforms.shiori.shared.parseISO8601

object NarratorsApi {
    suspend fun page(key: String, offered: String?, waitForCatalogue: Boolean = false): NarratorPage? {
        if (Showcase.isOn) return null
        return GraphQLClient.fetch(NarratorPageQuery(key, Optional.presentIfNotNull(offered), waitForCatalogue)).narratorPage?.narratorPageFields?.asDomain
    }

    suspend fun correct(key: String, correction: PersonCorrection): NarratorPage =
        GraphQLClient.perform(
            CorrectNarratorMutation(
                key = key,
                nationality = correction.nationality.optional(),
                birthYear = correction.birthYear.optional(),
                deathYear = correction.deathYear.optional(),
                biography = correction.biography.optional(),
                portraitUrl = Optional.presentIfNotNull(correction.portraitURL),
            ),
        ).correctNarrator.narratorPageFields.asDomain

    suspend fun portraitChoices(key: String): List<PortraitChoice> {
        if (Showcase.isOn) return emptyList()
        return GraphQLClient.fetch(NarratorPortraitChoicesQuery(key)).narratorPortraitChoices.orEmpty()
            .map { PortraitChoice(it.source.asDomain(), it.url, it.isCurrent) }
    }

    suspend fun setFavorite(key: String, favorite: Boolean): Boolean {
        if (Showcase.isOn) return favorite
        return GraphQLClient.perform(SetNarratorFavoriteMutation(key, favorite)).setNarratorFavorite
    }

    suspend fun myNarratorsPage(limit: Int, after: String?, order: AuthorListOrder): CursorPage<FollowedNarrator> {
        if (Showcase.isOn) return CursorPage(emptyList(), false, null)
        val page = GraphQLClient.fetch(MyNarratorsPageQuery(Optional.present(limit), Optional.presentIfNotNull(after), Optional.present(order.graphQL))).myNarratorsPage
        return CursorPage(
            page.items.map { row ->
                FollowedNarrator(row.key, row.name, row.indexLetter, row.portraitUrl, parseISO8601(row.shelvedAt), row.books.map { it.bookSummary.asBook }, row.favorite, row.surname)
            },
            page.hasMore,
            page.endCursor,
        )
    }
}

val NarratorPageFields.asDomain: NarratorPage
    get() = NarratorPage(
        key = narrator.key,
        name = narrator.name,
        portraitURL = narrator.portraitUrl,
        favorite = narrator.favorite,
        bookCount = narrator.bookCount,
        readCount = narrator.readCount,
        seriesCount = narrator.seriesCount,
        averageRating = narrator.averageRating,
        sagas = sagas.map { SeriesApi.followedRow(it.followedSeriesRow, it.volumes.map { v -> v.followedVolume }, it.catalogue?.catalogueSpine) },
        books = books.map { it.bookSummary.asBook },
        nationality = catalogue?.nationality,
        birthYear = catalogue?.birthYear,
        deathYear = catalogue?.deathYear,
        biography = catalogue?.biography,
        isAwaitingCatalogue = awaitingCatalogue,
    )
