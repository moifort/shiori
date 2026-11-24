package com.polyforms.shiori.features.wishlist.components.pages

import androidx.compose.runtime.Composable
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.components.pages.UnownedBookAddition
import com.polyforms.shiori.features.discover.components.pages.UnownedBookPage
import com.polyforms.shiori.features.discover.components.pages.UnownedBookStore
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistFixtures
import com.polyforms.shiori.features.wishlist.originLine
import com.polyforms.shiori.features.wishlist.release
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.book.BookState

/**
 * A book wished for, drawn as a book to have is ([UnownedBookPage]): the hero over the cover's
 * colours, where it came from on the detail line, the white button that orders it from its store
 * and the "+" that puts it on the pile or among the books read, which says "Envie" and asks before
 * taking the book off the list. Then its summary and its facts. No bell: nothing is awaited.
 */
@Composable
fun WishPage(
    wish: Wish,
    /** The wish once described, as a book's page draws it. */
    shown: Book,
    storeURL: String?,
    isDescribing: Boolean,
    onAdd: suspend (ReadingStatus) -> Unit,
    onRemove: suspend () -> Unit,
    /** Another cover picked for the book, for every reader. */
    onChooseCover: (() -> Unit)? = null,
) {
    UnownedBookPage(
        book = shown,
        releaseDate = null,
        store = storeURL?.let { UnownedBookStore(it, isAudible = wish.format == BookFormat.AUDIOBOOK) },
        isAlerted = false,
        onToggleBell = {},
        isDescribing = isDescribing,
        state = BookState(wish.originLine, SystemTint.GRAY),
        isOut = true,
        isAdded = false,
        additions = listOf(UnownedBookAddition.PILE, UnownedBookAddition.READ),
        onAdd = { addition -> onAdd(if (addition == UnownedBookAddition.READ) ReadingStatus.READ else ReadingStatus.TO_READ) },
        // The book is on the list: "+ Ajouter" says "Envie", and a tap on it asks before taking it off.
        isWished = true,
        onToggleWish = onRemove,
        onChooseCover = onChooseCover,
        recommendedBy = if (wish.origin == Wish.Origin.FRIEND) wish.originLabel else null,
    )
}

@Preview(showBackground = true)
@Composable
private fun WishPagePreview() = PreviewSurface {
    val wish = WishlistFixtures.wishes[0]
    WishPage(wish, wish.release.book(wish.id), "https://www.amazon.fr/s?k=Piranesi", isDescribing = false, onAdd = {}, onRemove = {})
}
