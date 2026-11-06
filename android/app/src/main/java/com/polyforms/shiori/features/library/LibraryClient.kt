package com.polyforms.shiori.features.library

import com.polyforms.shiori.features.book.BookApi
import com.polyforms.shiori.features.wishlist.Wishlist
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ReadingStatus

interface LibraryClient {
    suspend fun shelves(view: ShelvesView): LibraryShelves
    suspend fun shelf(query: ShelfQuery, limit: Int, after: String?): LibraryPageResult
    suspend fun pile(view: ShelvesView): Pile
    suspend fun lovedSeries(view: ShelvesView): List<FollowedSeries>
    suspend fun setStatus(id: String, status: ReadingStatus): Book
    suspend fun setFavorite(id: String, favorite: Boolean): Book
    suspend fun rate(id: String, stars: Double): Book
    suspend fun delete(id: String)
    suspend fun wishlist(): Wishlist

    companion object {
        val live: LibraryClient = object : LibraryClient {
            override suspend fun shelves(view: ShelvesView) = LibraryApi.shelves(view)
            override suspend fun shelf(query: ShelfQuery, limit: Int, after: String?) = LibraryApi.shelfPage(query, limit, after)
            override suspend fun pile(view: ShelvesView) = LibraryApi.pile(view)
            override suspend fun lovedSeries(view: ShelvesView) = LibraryApi.lovedSeries(view)
            override suspend fun setStatus(id: String, status: ReadingStatus) = BookApi.setStatus(id, status)
            override suspend fun setFavorite(id: String, favorite: Boolean) = BookApi.setFavorite(id, favorite)
            override suspend fun rate(id: String, stars: Double) = BookApi.rate(id, stars)
            override suspend fun delete(id: String) = BookApi.delete(id)
            override suspend fun wishlist() = WishlistApi.wishlist()
        }
    }
}
