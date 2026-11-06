package com.polyforms.shiori.features.narrators

import com.polyforms.shiori.features.authors.AuthorListOrder
import com.polyforms.shiori.features.authors.PersonCorrection
import com.polyforms.shiori.features.authors.PortraitChoice
import com.polyforms.shiori.shared.CursorPage

/** What a narrator's page and the Narrators shelf ask of the server. */
interface NarratorsClient {
    suspend fun page(key: String, name: String?): NarratorPage?
    suspend fun catalogue(key: String, name: String?): NarratorPage?
    suspend fun correct(key: String, correction: PersonCorrection): NarratorPage?
    suspend fun portraitChoices(key: String): List<PortraitChoice>
    suspend fun setFavorite(key: String, favorite: Boolean): Boolean
    suspend fun list(limit: Int, after: String?, order: AuthorListOrder): CursorPage<FollowedNarrator>

    companion object {
        val live: NarratorsClient = object : NarratorsClient {
            override suspend fun page(key: String, name: String?) = NarratorsApi.page(key, name)
            override suspend fun catalogue(key: String, name: String?) = NarratorsApi.page(key, name, waitForCatalogue = true)
            override suspend fun correct(key: String, correction: PersonCorrection) = NarratorsApi.correct(key, correction)
            override suspend fun portraitChoices(key: String) = NarratorsApi.portraitChoices(key)
            override suspend fun setFavorite(key: String, favorite: Boolean) = NarratorsApi.setFavorite(key, favorite)
            override suspend fun list(limit: Int, after: String?, order: AuthorListOrder) = NarratorsApi.myNarratorsPage(limit, after, order)
        }
    }
}
