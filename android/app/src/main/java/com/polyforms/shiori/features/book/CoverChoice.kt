package com.polyforms.shiori.features.book

import com.polyforms.shiori.graphql.BookCoverChoicesQuery
import com.polyforms.shiori.graphql.type.CoverSource

/** A cover the reader may pick for a book, and where it was found. */
data class CoverChoice(val source: Source, val url: String, val isCurrent: Boolean) {
    enum class Source { KINDLE, PHOTO, AMAZON, OPEN_LIBRARY, OTHER_EDITION, WEB }

    val id: String get() = url

    companion object {
        val previews = listOf(
            CoverChoice(Source.OPEN_LIBRARY, "https://covers.openlibrary.org/b/isbn/9782352942832-L.jpg?default=false", true),
            CoverChoice(Source.KINDLE, "https://m.media-amazon.com/images/P/2352943558.01._SCLZZZZZZZ_.jpg", false),
            CoverChoice(Source.AMAZON, "https://m.media-amazon.com/images/P/2352942837.01._SCLZZZZZZZ_.jpg", false),
            CoverChoice(Source.OTHER_EDITION, "https://covers.openlibrary.org/b/isbn/9782352943556-L.jpg?default=false", false),
        )
    }
}

/** A source added after this build shipped is a cover left out rather than guessed. */
val BookCoverChoicesQuery.BookCoverChoice.asDomain: CoverChoice?
    get() {
        val source = when (source) {
            CoverSource.KINDLE -> CoverChoice.Source.KINDLE
            CoverSource.PHOTO -> CoverChoice.Source.PHOTO
            CoverSource.AMAZON -> CoverChoice.Source.AMAZON
            CoverSource.OPEN_LIBRARY -> CoverChoice.Source.OPEN_LIBRARY
            CoverSource.OTHER_EDITION -> CoverChoice.Source.OTHER_EDITION
            CoverSource.WEB -> CoverChoice.Source.WEB
            else -> return null
        }
        return CoverChoice(source, url, current)
    }
