package com.polyforms.shiori.features.book

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.VolumeKind
import java.time.Instant
import java.time.temporal.ChronoUnit

/** The book page's previews and tests, as `Book.preview` and its neighbours on iOS. */
object BookFixtures {
    val preview = Book(
        id = "1",
        title = "Le Nom du vent",
        authors = listOf("Patrick Rothfuss"),
        format = BookFormat.AUDIOBOOK,
        publisher = "Bragelonne",
        firstPublishedIn = 2007,
        editionYear = 2015,
        synopsis = "Kvothe raconte sa propre légende : l'enfance sur les routes, la misère à Tarbean, l'Université et la magie qu'on y apprend.",
        genre = BookGenre.FANTASY,
        subgenres = listOf("Roman initiatique", "Aventure"),
        pageCount = 662,
        audibleURL = "https://www.audible.fr/pd/B00X57B4KE",
        amazonURL = "https://www.amazon.fr/s?k=Le+Nom+du+vent+Patrick+Rothfuss&i=audible&tag=polyforms09-21",
        isbn13 = "9782352943556",
        series = SeriesMembership("s1", "Chronique du tueur de roi", 1, VolumeKind.MAIN),
        status = ReadingStatus.READING,
        note = "La scène de l'auberge, au début, vaut le livre entier.",
        recommendation = BookRecommendation("Marie Curie", "Lis-le cet été."),
        hidden = true,
        addedAt = Instant.now().minus(32, ChronoUnit.DAYS),
        startedAt = Instant.now().minus(20, ChronoUnit.DAYS),
    )

    val previewDropped get() = preview.copy(durationMinutes = 1662, listeningProgress = 64, status = ReadingStatus.DROPPED)

    val previewPaper get() = preview.copy(format = BookFormat.BOOK, media = listOf(BookMedium.PRINT), currentPage = 214)

    val previewFromShelf = Book(
        id = "2",
        title = "One Piece",
        authors = listOf("Eiichiro Oda"),
        format = BookFormat.MANGA,
        language = BookLanguage.FR,
        series = SeriesMembership("s2", "One Piece", 5, VolumeKind.MAIN),
        coverURL = "https://m.media-amazon.com/images/P/2723434826.01._SCLZZZZZZZ_.jpg",
        status = ReadingStatus.TO_READ,
        awaitingDescription = true,
    )
}
