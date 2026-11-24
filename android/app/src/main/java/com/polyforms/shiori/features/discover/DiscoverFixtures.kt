package com.polyforms.shiori.features.discover

import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import java.time.Instant

/** The pages of books nobody here holds, drawn in previews and from `--es preview`. */
object DiscoverFixtures {
    /** A winner in English nobody awaited yet: both formats left to await. */
    val awardWinner = AwardWinner(
        id = "the-buffalo-hunter-hunter--stephen-graham-jones",
        format = ReleaseFormat.BOOK,
        title = "The Buffalo Hunter Hunter",
        originalTitle = "The Buffalo Hunter Hunter",
        originalLanguage = BookLanguage.EN,
        authors = listOf("Stephen Graham Jones"),
        mentions = listOf(AwardMention(LiteraryAward.NEBULA, 2026)),
        state = AwaitedState.UNANNOUNCED,
        watched = false,
        date = null,
        coverURL = null,
        storeURL = null,
        awaitableFormats = listOf(ReleaseFormat.BOOK, ReleaseFormat.AUDIOBOOK),
        awaitedEditionId = null,
    )

    /** A Goncourt in a French app: out in print, only its recording to await. */
    val goncourtWinner = AwardWinner(
        id = "la-maison-vide--laurent-mauvignier",
        format = ReleaseFormat.BOOK,
        title = "La Maison vide",
        originalTitle = "La Maison vide",
        originalLanguage = BookLanguage.FR,
        authors = listOf("Laurent Mauvignier"),
        mentions = listOf(AwardMention(LiteraryAward.GONCOURT, 2026)),
        state = AwaitedState.AVAILABLE,
        watched = false,
        date = null,
        coverURL = null,
        storeURL = null,
        awaitableFormats = listOf(ReleaseFormat.AUDIOBOOK),
        awaitedEditionId = null,
    )

    /** A recording awaited from a friend's shelf, out: the friend recommended it. */
    val awaitedFromFriend = AwaitedEdition(
        id = "preview-friend",
        format = ReleaseFormat.AUDIOBOOK,
        state = AwaitedState.AVAILABLE,
        title = "Seul sur Mars",
        originalTitle = "The Martian",
        originalLanguage = BookLanguage.EN,
        authors = listOf("Andy Weir"),
        date = "2026-10-28",
        coverURL = null,
        storeURL = "https://www.audible.fr/search?keywords=Seul%20sur%20Mars%20Andy%20Weir",
        awaitedAt = Instant.now().minusSeconds(20 * 86_400),
        bookId = "friend-book",
        ownerId = "guillaume",
    ).copy(recommendedBy = "Guillaume")
}

/** The same release, described as the preview volume is. */
val Release.describedForPreview: Release
    get() = copy(
        publisher = "Bragelonne",
        synopsis = "Carl et Princesse Donut descendent au neuvième étage du donjon, où les règles changent encore.",
        genre = BookGenre.FANTASY,
        narrators = listOf("Jeff Hays"),
        durationMinutes = 1_260,
        described = true,
    )
