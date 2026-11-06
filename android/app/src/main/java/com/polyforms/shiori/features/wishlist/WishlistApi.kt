package com.polyforms.shiori.features.wishlist

import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.asDomain
import com.polyforms.shiori.graphql.RemoveWishMutation
import com.polyforms.shiori.graphql.WishBookMutation
import com.polyforms.shiori.graphql.WishFriendBookMutation
import com.polyforms.shiori.graphql.WishlistQuery
import com.polyforms.shiori.graphql.fragment.WishFields
import com.polyforms.shiori.graphql.type.SeriesPlacementInput
import com.polyforms.shiori.graphql.type.WishOrigin
import com.polyforms.shiori.graphql.type.WishedBookInput
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.asDomain
import com.polyforms.shiori.shared.asOptional
import com.polyforms.shiori.shared.graphQL
import com.polyforms.shiori.shared.parseISO8601
import com.polyforms.shiori.shared.present
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import java.time.Instant

object WishlistApi {
    private val changes = MutableSharedFlow<Unit>(extraBufferCapacity = 4)
    val didChange: SharedFlow<Unit> get() = changes

    suspend fun wishlist(): Wishlist {
        if (Showcase.isOn) return Wishlist()
        val data = GraphQLClient.fetch(WishlistQuery()).wishlist
        return Wishlist(data.wishes.map { it.wishFields.asDomain }, data.awaited.map { it.awaitedEditionFields.asDomain })
    }

    suspend fun wish(draft: BookDraft, origin: Wish.Origin, label: String? = null): Wish {
        val book = WishedBookInput(
            authors = draft.authors.ifEmpty { null }.present(),
            coverUrl = draft.coverURL.asOptional(),
            format = draft.format.graphQL,
            isbn13 = draft.isbn13.asOptional(),
            language = draft.language?.graphQL.present(),
            series = draft.series?.let { SeriesPlacementInput(name = it.name, volume = it.volume.present()) }.present(),
            title = draft.title,
        )
        val data = GraphQLClient.perform(WishBookMutation(book, WishOrigin.safeValueOf(origin.name), Optional.presentIfNotNull(label)), changesLibrary = false)
        changes.tryEmit(Unit)
        return data.wishBook.wishFields.asDomain
    }

    suspend fun wish(friendId: String, bookId: String): Wish {
        val data = GraphQLClient.perform(WishFriendBookMutation(friendId, bookId), changesLibrary = false)
        changes.tryEmit(Unit)
        return data.wishFriendBook.wishFields.asDomain
    }

    suspend fun remove(id: String) {
        GraphQLClient.perform(RemoveWishMutation(id), changesLibrary = false)
        changes.tryEmit(Unit)
    }
}

val WishFields.asDomain: Wish
    get() = Wish(
        id = id,
        title = title,
        authors = authors,
        format = format.asDomain,
        language = language?.asDomain,
        seriesName = seriesName,
        volume = volume,
        coverURL = coverUrl,
        isbn13 = isbn13,
        origin = Wish.Origin.entries.firstOrNull { it.name == origin.rawValue } ?: Wish.Origin.DISCOVERY,
        originLabel = originLabel,
        friendId = friendId,
        wishedAt = parseISO8601(wishedAt) ?: Instant.now(),
    )
