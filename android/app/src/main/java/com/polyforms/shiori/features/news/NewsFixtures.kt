package com.polyforms.shiori.features.news

import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.AwardMention
import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.AwardWinner
import com.polyforms.shiori.features.discover.LiteraryAward
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.account.AvatarHero
import java.time.Instant
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/**
 * The Actu tab's fixtures, as iOS's NewsFixtures: real covers, so a preview or an emulator capture
 * looks like the app in use.
 */
object NewsFixtures {
    private fun openLibrary(isbn: String) = "https://covers.openlibrary.org/b/isbn/$isbn-L.jpg"
    private fun openLibrary(id: Int) = "https://covers.openlibrary.org/b/id/$id-L.jpg"
    private fun amazon(isbn10: String) = "https://m.media-amazon.com/images/P/$isbn10.01._SCLZZZZZZZ_.jpg"
    private fun hoursAgo(hours: Long) = Instant.now().minus(hours, ChronoUnit.HOURS)
    private fun isoDay(daysAhead: Long) = LocalDate.now().plusDays(daysAhead).toString()
    private fun isoThisMonth(day: Int) = LocalDate.now().withDayOfMonth(day).toString()
    private fun isoMonth(monthsAhead: Long) = LocalDate.now().plusMonths(monthsAhead).toString().take(7)
    private fun isoYear(yearsAhead: Int) = (LocalDate.now().year + yearsAhead).toString()

    val events = listOf(
        FeedEvent(
            "marc~loved~arabe", FeedEventKind.LOVED, hoursAgo(3), "marc", "Marc", AvatarHero.GANDALF, null, "arabe", "L'Arabe du futur",
            listOf("Riad Sattouf"), BookFormat.BANDE_DESSINEE, null, openLibrary(12636991), 5.0, 0, true,
        ),
        FeedEvent(
            "sophie~started~vagabond", FeedEventKind.STARTED, hoursAgo(5), "sophie", "Sophie", AvatarHero.KATNISS, null, "vagabond", "Vagabond",
            listOf("Takehiko Inoue"), BookFormat.MANGA, null, openLibrary(863044), null, 3, false,
        ),
        FeedEvent(
            "lea~finished~dune", FeedEventKind.FINISHED, hoursAgo(72), "lea", "Léa", AvatarHero.HERMIONE, null, "dune", "Dune",
            listOf("Frank Herbert"), BookFormat.BOOK, BookLanguage.EN, openLibrary("9780441013593"), 4.0, 0, false,
        ),
    )

    /** Marc and Hugo starting Vagabond after Sophie: one line. */
    val sameStart = listOf(
        FeedEvent(
            "marc~started~vagabond", FeedEventKind.STARTED, hoursAgo(6), "marc", "Marc", AvatarHero.GANDALF, null, "vagabond-marc", "Vagabond",
            listOf("Takehiko Inoue"), BookFormat.MANGA, null, openLibrary(863044), null, 3, false,
        ),
        FeedEvent(
            "hugo~started~vagabond", FeedEventKind.STARTED, hoursAgo(7), "hugo", "Hugo", null, null, "vagabond-hugo", "Vagabond",
            listOf("Takehiko Inoue"), BookFormat.MANGA, null, openLibrary(863044), null, 3, false,
        ),
    )

    val narrator = NarratorNews(
        "gabay~fondation", "bernard-gabay", "Bernard Gabay", "Fondation", listOf("Isaac Asimov"), LocalDate.now().toString(),
        amazon("2070360539"), BookFormat.AUDIOBOOK,
    )

    private val pierce = UpcomingRelease.AuthorRef("pierce-brown", "Pierce Brown", true, null)

    /** The favourite author's announcement. */
    val authorRelease = UpcomingRelease(
        "saga~red-rising~6", ReleaseSource.SAGA, BookFormat.BOOK, "Light Bringer", listOf("Pierce Brown"), isoDay(48), openLibrary(15157697),
        "Red Rising", 6, pierce, 5.0, true,
    )

    /** Out lately among what the reader follows. */
    val released = listOf(
        UpcomingRelease(
            "saga~berserk~42", ReleaseSource.SAGA, BookFormat.MANGA, "Berserk, tome 42", listOf("Kentaro Miura"), isoDay(-6), openLibrary(15166261),
            "Berserk", 42, null, null, true,
        ),
        UpcomingRelease(
            "awaited~projet-derniere-chance", ReleaseSource.AWAITED, BookFormat.AUDIOBOOK, "Projet Dernière Chance", listOf("Andy Weir"), isoDay(-12),
            openLibrary("9780593135204"), null, null, null, null, false,
        ),
        UpcomingRelease(
            "saga~expanse~9", ReleaseSource.SAGA, BookFormat.BOOK, "The Expanse, tome 9", listOf("James S. A. Corey"), isoDay(-45),
            openLibrary("9780316332941"), "The Expanse", 9, null, 4.0, false, language = BookLanguage.EN,
        ),
    )

    val upcoming = listOf(
        authorRelease,
        UpcomingRelease(
            "author~piranesi", ReleaseSource.AUTHOR, BookFormat.BOOK, "Piranesi", listOf("Susanna Clarke"), isoThisMonth(4), openLibrary("9781635575637"),
            null, null, UpcomingRelease.AuthorRef("susanna-clarke", "Susanna Clarke", true, null), null, false,
        ),
        UpcomingRelease(
            "saga~berserk~43", ReleaseSource.SAGA, BookFormat.MANGA, "Berserk, tome 43", listOf("Kentaro Miura"), isoThisMonth(4), openLibrary(15166261),
            "Berserk", 43, null, null, true,
        ),
        UpcomingRelease(
            "awaited~seul-sur-mars", ReleaseSource.AWAITED, BookFormat.AUDIOBOOK, "Seul sur Mars", listOf("Andy Weir"), isoThisMonth(20),
            openLibrary("9780553418026"), null, null, null, null, false,
        ),
        UpcomingRelease(
            "saga~expanse~10", ReleaseSource.SAGA, BookFormat.BOOK, "The Expanse, tome 10", listOf("James S. A. Corey"), isoMonth(8),
            openLibrary("9780316332941"), "The Expanse", 10, null, 4.0, false,
        ),
        UpcomingRelease(
            "saga~frieren~16", ReleaseSource.SAGA, BookFormat.MANGA, "Frieren, tome 16", listOf("Kanehito Yamada"), isoYear(2), null,
            "Frieren", 16, null, null, true,
        ),
        UpcomingRelease(
            "awaited~portes-de-pierre", ReleaseSource.AWAITED, BookFormat.BOOK, "Les Portes de pierre", listOf("Patrick Rothfuss"), null, null,
            null, null, null, null, false,
        ),
        UpcomingRelease(
            "author~weir-sans-titre", ReleaseSource.AUTHOR, BookFormat.BOOK, null, listOf("Andy Weir"), null, null, null, null,
            UpcomingRelease.AuthorRef("andy-weir", "Andy Weir", false, null), null, false,
        ),
    )

    /** The wish list rail as the server orders it: two to come, one out lately, one out already. */
    val wishlist = listOf(
        UpcomingRelease(
            "awaited~fourth-wing-4", ReleaseSource.AWAITED, BookFormat.BOOK, "Fourth Wing, tome 4", listOf("Rebecca Yarros"), isoDay(14),
            openLibrary("9781649374042"), "Fourth Wing", 4, null, null, false,
        ),
        UpcomingRelease(
            "awaited~terminus-etoiles", ReleaseSource.AWAITED, BookFormat.AUDIOBOOK, "Terminus Étoiles", listOf("Alfred Bester"), isoDay(15),
            openLibrary("9780679767800"), null, null, null, null, false,
        ),
        UpcomingRelease(
            "awaited~projet-derniere-chance", ReleaseSource.AWAITED, BookFormat.BOOK, "Projet Dernière Chance", listOf("Andy Weir"), isoDay(-12),
            openLibrary("9780593135204"), null, null, null, null, false,
        ),
        UpcomingRelease(
            "awaited~seul-sur-mars-audio", ReleaseSource.AWAITED, BookFormat.AUDIOBOOK, "Seul sur Mars", listOf("Andy Weir"), "2015-02-12",
            openLibrary("9780553418026"), null, null, null, null, false,
        ),
    )

    private fun suggestion(id: String, title: String, original: String, author: String, short: String, reason: String) = Suggestion(
        id = id, format = ReleaseFormat.BOOK, title = title, originalTitle = original, originalLanguage = BookLanguage.EN, authors = listOf(author),
        reason = reason, short = short, references = emptyList(), state = AwaitedState.UNANNOUNCED, watched = false, date = null, coverURL = null,
        storeURL = null, awaitableFormats = listOf(ReleaseFormat.BOOK), awaitedEditionId = null,
    )

    val suggestions = listOf(
        suggestion(
            "lies", "Les Salauds Gentilshommes", "The Lies of Locke Lamora", "Scott Lynch", "comme Gagner la guerre",
            "Un héros rusé et une narration brillante, avec le souffle de la Chronique du Tueur de Roi et la verve de Gagner la guerre.",
        ),
        suggestion(
            "silo", "Silo", "Wool", "Hugh Howey", "comme Métro",
            "Une société close et mystérieuse, dans la veine de Métro de Glukhovsky, avec une vraie tension à chaque chapitre.",
        ),
    )

    private fun winner(id: String, title: String, author: String, award: LiteraryAward, cover: String?, language: BookLanguage) = AwardWinner(
        id = id, format = ReleaseFormat.BOOK, title = title, originalTitle = title, originalLanguage = language, authors = listOf(author),
        mentions = listOf(AwardMention(award, LocalDate.now().year)), state = AwaitedState.AVAILABLE, watched = false, date = null,
        coverURL = cover, storeURL = null, awaitableFormats = emptyList(), awaitedEditionId = null, key = id,
    )

    val awards = listOf(
        AwardSection(BookGenre.FANTASY, listOf(winner("the-tainted-cup", "The Tainted Cup", "Robert Jackson Bennett", LiteraryAward.HUGO, openLibrary("9780593723180"), BookLanguage.EN))),
        AwardSection(BookGenre.LITERARY_FICTION, listOf(winner("houris", "Houris", "Kamel Daoud", LiteraryAward.GONCOURT, openLibrary("9782073089877"), BookLanguage.FR))),
    )

    /** The whole agenda the page previews draw. */
    fun agenda(events: List<FeedEvent> = this.events + sameStart): NewsAgenda = NewsAgenda.of(
        released = NewsFeedLayout.released(released, listOf(narrator), null),
        events = events,
        upcoming = ReleaseCalendar(upcoming).dated,
        announced = upcoming,
        wishlist = wishlist,
        suggestions = suggestions,
        awards = awards,
    )
}
