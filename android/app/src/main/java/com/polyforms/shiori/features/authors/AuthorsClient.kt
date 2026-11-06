package com.polyforms.shiori.features.authors

import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.CursorPage

/** What an author's page and the Authors shelf ask of the server. */
interface AuthorsClient {
    suspend fun page(key: String, offered: String?): AuthorPage?
    suspend fun catalogue(key: String, offered: String?): AuthorPage?
    suspend fun correct(key: String, correction: PersonCorrection): AuthorPage?
    suspend fun portraitChoices(key: String): List<PortraitChoice>
    suspend fun setFavorite(key: String, favorite: Boolean): Boolean
    suspend fun addBook(draft: BookDraft, lookUp: BookAddition.LookUp?): Book
    suspend fun myAuthorsPage(limit: Int, after: String?, order: AuthorListOrder): CursorPage<FollowedAuthor>

    companion object {
        val live: AuthorsClient = object : AuthorsClient {
            override suspend fun page(key: String, offered: String?) = AuthorsApi.page(key, offered)
            override suspend fun catalogue(key: String, offered: String?) = AuthorsApi.page(key, offered, waitForCatalogue = true)
            override suspend fun correct(key: String, correction: PersonCorrection) = AuthorsApi.correct(key, correction)
            override suspend fun portraitChoices(key: String) = AuthorsApi.portraitChoices(key)
            override suspend fun setFavorite(key: String, favorite: Boolean) = AuthorsApi.setFavorite(key, favorite)
            override suspend fun addBook(draft: BookDraft, lookUp: BookAddition.LookUp?) = BookAddition.add(draft, lookUp, AnalyticsEvent.BookSource.AUTHOR)
            override suspend fun myAuthorsPage(limit: Int, after: String?, order: AuthorListOrder) = AuthorsApi.myAuthorsPage(limit, after, order)
        }
    }
}
