package com.polyforms.shiori.features.wishlist

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.DiscoverClient
import com.polyforms.shiori.features.discover.Release
import com.polyforms.shiori.features.discover.ReleaseDescriber
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.ReleaseItem
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError

/**
 * A book wished for, on its own page: its description, asked for when it opens, and what the reader
 * makes of it — on the pile, read already, or off the list.
 */
class WishViewModel(val wish: Wish, private val client: WishlistClient, discover: DiscoverClient) {
    private val describer = ReleaseDescriber(wish.release) { discover.describe(ReleaseItem.Wish(wish.id)) }

    /** The wish as the list drew it, then as the server described it. */
    val shown: Book get() = describer.release.book("wish-${wish.id}")
    val storeURL: String? get() = describer.release.storeURL
    val isDescribing: Boolean get() = describer.isDescribing
    val releaseKey: String get() = describer.release.key

    fun drawCover(url: String) = describer.drawCover(url)

    /** Why an action failed, for the alert; null once read. */
    var actionError by mutableStateOf<String?>(null)

    suspend fun describe() = describer.describe()

    /** Onto the shelf: the wish then goes on its own. Says whether it went. */
    suspend fun add(status: ReadingStatus): Boolean = act { client.addBook(wish.draft(status)) }

    /** Off the list. Says whether it went. */
    suspend fun remove(): Boolean = act { client.remove(wish.id) }

    private suspend fun act(work: suspend () -> Unit): Boolean = try {
        // The pile and the list read it again on the notice the call posts.
        work()
        true
    } catch (error: Throwable) {
        if (isCancellation(error)) throw error
        actionError = reportError(error)
        false
    }
}

/** The release its page starts from: what the list knew of it, out, to be described. */
val Wish.release: Release
    get() = Release.listed(
        key = "wish-$id",
        title = title,
        authors = authors,
        releaseFormat = if (format == BookFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK,
        state = AwaitedState.AVAILABLE,
        format = format,
        language = language,
        watched = false,
        isbn13 = isbn13,
        coverURL = coverURL,
    )

/** Where it came from, under its author: the friend who recommended it, else the origin its cover is labelled with. */
val Wish.originLine: String
    get() = if (origin == Wish.Origin.FRIEND && originLabel != null) {
        L("Liste d'envies · conseillé par %@", originLabel)
    } else {
        L("Liste d'envies · %@", originCaption)
    }
