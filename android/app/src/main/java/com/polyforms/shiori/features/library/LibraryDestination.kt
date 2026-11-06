package com.polyforms.shiori.features.library

import androidx.compose.runtime.Composable
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.authors.AuthorShelfScreen
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.narrators.NarratorDestination
import com.polyforms.shiori.features.narrators.NarratorScreen
import com.polyforms.shiori.features.narrators.NarratorShelfScreen
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.series.SeriesShelfFilter
import com.polyforms.shiori.features.series.SeriesShelfScreen
import com.polyforms.shiori.features.series.SetAsideSeriesScreen
import com.polyforms.shiori.features.wishlist.WishlistScreen
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.ReadingStatus

/** Every page the Library opens. */
sealed interface LibraryDestination {
    data class BookPage(val book: Book) : LibraryDestination
    data class Shelf(val shelf: BookShelf, val view: ShelvesView = ShelvesView(), val status: ReadingStatus? = null, val formats: List<BookFormat> = emptyList()) : LibraryDestination
    data class SeriesShelf(val filter: SeriesShelfFilter = SeriesShelfFilter.ALL) : LibraryDestination
    data object SetAsideSeries : LibraryDestination
    data class Series(val id: String) : LibraryDestination
    data object Authors : LibraryDestination
    data class Author(val author: AuthorDestination) : LibraryDestination
    data object Narrators : LibraryDestination
    data class Narrator(val narrator: NarratorDestination) : LibraryDestination
    data class Genre(val genre: BookGenre) : LibraryDestination
    data object Wishlist : LibraryDestination

    companion object {
        fun of(request: LibraryRequest): LibraryDestination? = when (val filter = request.filter) {
            is LibraryFilter.Status -> when (filter.status) {
                ReadingStatus.TO_READ -> Shelf(BookShelf.TO_READ)
                ReadingStatus.READ -> Shelf(BookShelf.READ)
                ReadingStatus.READING -> Shelf(BookShelf.RECENT, status = ReadingStatus.READING)
                ReadingStatus.DROPPED -> Shelf(BookShelf.DROPPED)
            }
            LibraryFilter.Favorites -> Shelf(BookShelf.LOVED)
            null -> null
        }
    }
}

@Composable
fun LibraryDestinationScreen(destination: LibraryDestination, client: LibraryClient = LibraryClient.live) {
    when (destination) {
        is LibraryDestination.BookPage -> BookScreen(destination.book.id)
        is LibraryDestination.Shelf -> when (destination.shelf) {
            BookShelf.ALL -> BookMosaicScreen(destination.view, destination.formats, client)
            BookShelf.TO_READ -> PileScreen(destination.view, client)
            else -> BookShelfScreen(destination.shelf, destination.view, destination.status, destination.formats, client)
        }
        is LibraryDestination.SeriesShelf -> SeriesShelfScreen(destination.filter)
        LibraryDestination.SetAsideSeries -> SetAsideSeriesScreen()
        is LibraryDestination.Series -> SeriesScreen(destination.id)
        LibraryDestination.Authors -> AuthorShelfScreen()
        is LibraryDestination.Author -> AuthorScreen(destination.author.key, destination.author.name)
        LibraryDestination.Narrators -> NarratorShelfScreen(client)
        is LibraryDestination.Narrator -> NarratorScreen(destination.narrator.key, destination.narrator.name)
        is LibraryDestination.Genre -> LibraryShelvesScreen(destination.genre, client)
        LibraryDestination.Wishlist -> WishlistScreen()
    }
}
