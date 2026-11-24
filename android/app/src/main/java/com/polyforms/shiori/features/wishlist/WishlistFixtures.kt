package com.polyforms.shiori.features.wishlist

import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import java.time.Instant

/** The wishlist drawn in previews and from `--es preview`. */
object WishlistFixtures {
    private fun cover(isbn: String) = "https://covers.openlibrary.org/b/isbn/$isbn-L.jpg"
    private fun daysAgo(days: Long): Instant = Instant.now().minusSeconds(days * 86_400)

    val wishes: List<Wish> = listOf(
        Wish("hyperion", "Hypérion", listOf("Dan Simmons"), BookFormat.BOOK, BookLanguage.FR, "Les Cantos d'Hypérion", 1, cover("9782266111560"), "9782266111560", Wish.Origin.FRIEND, "Camille", "camille", daysAgo(1)),
        Wish("nom-du-vent", "Le Nom du vent", listOf("Patrick Rothfuss"), BookFormat.BOOK, BookLanguage.FR, null, null, cover("9780756404741"), "9782352943259", Wish.Origin.FRIEND, "Guillaume", "guillaume", daysAgo(2)),
        Wish("piranesi", "Piranesi", listOf("Susanna Clarke"), BookFormat.BOOK, BookLanguage.EN, null, null, cover("9781526622426"), "9781526622426", Wish.Origin.DISCOVERY, null, null, daysAgo(3)),
        Wish("buffalo", "The Buffalo Hunter Hunter", listOf("Stephen Graham Jones"), BookFormat.BOOK, BookLanguage.EN, null, null, cover("9781668057834"), null, Wish.Origin.AWARD, "Nebula", null, daysAgo(4)),
        Wish("dune", "Dune", listOf("Frank Herbert"), BookFormat.BOOK, BookLanguage.FR, "Dune", 1, cover("9782266320481"), null, Wish.Origin.SCAN, null, null, daysAgo(5)),
    )

    val wishlist = Wishlist(
        wishes = wishes,
        awaited = listOf(
            AwaitedEdition(
                "red-god", ReleaseFormat.BOOK, AwaitedState.ANNOUNCED, "Red God", "Red God", BookLanguage.EN, listOf("Pierce Brown"),
                "2026-12-18", cover("9780425285961"), null, Instant.now(), "red-rising", "me",
            ),
            AwaitedEdition(
                "martian", ReleaseFormat.AUDIOBOOK, AwaitedState.AVAILABLE, "Seul sur Mars", "The Martian", BookLanguage.EN, listOf("Andy Weir"),
                "2026-10-28", cover("9780553418026"), null, Instant.now(), "martian", "me",
            ),
            AwaitedEdition(
                "wind-and-truth", ReleaseFormat.BOOK, AwaitedState.UNANNOUNCED, "Wind and Truth", "Wind and Truth", BookLanguage.EN, listOf("Brandon Sanderson"),
                null, cover("9781250319180"), null, Instant.now(), "wind", "me",
            ),
        ),
    )
}
