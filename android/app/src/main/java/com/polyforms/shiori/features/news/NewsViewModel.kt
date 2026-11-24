package com.polyforms.shiori.features.news

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId

/**
 * The Actualités tab's state: the friends' moves page by page and the releases, discoveries and
 * prizes the agenda is laid from. The tab opens on what it last showed: a `SnapshotCache` hands it
 * back from disk before a byte is asked of the network, and the answer slides in over it.
 *
 * @param caching off in tests, which must neither read nor leave a snapshot on disk.
 */
class NewsViewModel(private val client: NewsClient, private val scope: CoroutineScope, caching: Boolean = true) {
    /** What the tab opens on: the feed's first page and everything around it. */
    @Serializable
    private data class Snapshot(
        val events: List<FeedEvent>,
        val releases: List<UpcomingRelease>,
        val yearReleases: List<UpcomingRelease>,
        val narratorNews: List<NarratorNews>,
        val awardSections: List<AwardSection> = emptyList(),
        val suggestions: List<Suggestion> = emptyList(),
        val wishlistReleases: List<UpcomingRelease> = emptyList(),
    )

    private val cache = if (caching) SnapshotCache("news", 5, Snapshot.serializer()) else null
    private val preferences = if (caching) AppContext.get().getSharedPreferences("shiori", Context.MODE_PRIVATE) else null

    var events by mutableStateOf<List<FeedEvent>>(emptyList())
        private set
    var releases by mutableStateOf<List<UpcomingRelease>>(emptyList())
        private set
    var yearReleases by mutableStateOf<List<UpcomingRelease>>(emptyList())
        private set

    /** The wish list rail, in the server's order. */
    var wishlistReleases by mutableStateOf<List<UpcomingRelease>>(emptyList())
        private set
    var narratorNews by mutableStateOf<List<NarratorNews>>(emptyList())
        private set

    /** The prizes' winners and the month's discoveries. */
    var awardSections by mutableStateOf<List<AwardSection>>(emptyList())
        private set
    var suggestions by mutableStateOf<List<Suggestion>>(emptyList())
        private set

    /** Discoveries and winners turned down: gone from the page at once. */
    var dismissed by mutableStateOf(emptySet<String>())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var isLoadingMore by mutableStateOf(false)
        private set
    var hasLoaded by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var pageFailed by mutableStateOf(false)
        private set

    /** Books the reader just took, greyed out at once: a friend's by its book id, a release by its row id. */
    var taken by mutableStateOf(emptySet<String>())
        private set

    /** What the reader made of the cards' buttons on this visit. */
    var wished by mutableStateOf(NewsWishes())
        private set
    var awaited by mutableStateOf(emptySet<String>())
        private set
    var alertsSilenced by mutableStateOf(false)
        private set

    /** The pill chosen; null is "Tout". */
    var format by mutableStateOf<BookFormat?>(null)

    /** The friend picked among the stories; null is everyone. */
    var friendId by mutableStateOf<String?>(null)

    /** The wish each key's book became, so a second tap takes it back. */
    private val wishIds = mutableMapOf<String, String>()

    /** The book a card's "+ Ajouter" put on the shelf, and the edition it awaited, by the card's key. */
    private val bookIds = mutableMapOf<String, String>()
    private val editionIds = mutableMapOf<String, String>()
    private var moreOnServer = false
    private var cursor: String? = null
    private var generation = 0
    private var friendsSeenAt: Instant? = preferences?.getLong(FRIENDS_SEEN, 0)?.takeIf { it > 0 }?.let(Instant::ofEpochMilli)
    private var ringsSeenAt = friendsSeenAt

    init {
        cache?.read()?.let {
            events = it.events
            releases = it.releases
            yearReleases = it.yearReleases
            narratorNews = it.narratorNews
            awardSections = it.awardSections
            suggestions = it.suggestions
            wishlistReleases = it.wishlistReleases
        }
    }

    /** The Découvrir page: the week's agenda, what each day brought, the days to come. */
    fun agenda(now: Instant = Instant.now()): NewsAgenda = NewsAgenda.of(
        released = NewsFeedLayout.released(yearReleases, narratorNews, null, now),
        events = shownEvents,
        upcoming = calendar(now).dated,
        announced = releases,
        wishlist = wishlistReleases,
        suggestions = suggestions,
        awards = awardSections,
        dismissed = dismissed,
        now = now,
    )

    /** Every move, the books just taken marked as held. */
    val shownEvents: List<FeedEvent> get() = events.map { if (it.bookId in taken) it.copy(inLibrary = true) else it }

    fun released(now: Instant = Instant.now()) = NewsFeedLayout.released(yearReleases, narratorNews, format, now)

    /** The one feed: releases and friends' moves of the last thirty days. */
    fun feedSections(now: Instant = Instant.now()) = NewsFeedLayout.feedSections(released(now), shownEvents, format, friendId, now)

    /** The pills over the feed: the formats its unnarrowed lines are in. */
    fun pillFormats(now: Instant = Instant.now()): List<BookFormat> {
        val everything = NewsFeedLayout.feedSections(NewsFeedLayout.released(yearReleases, narratorNews, null, now), shownEvents, null, friendId, now)
        return NewsFeedLayout.pillFormats(everything, format)
    }

    /** Everything announced, whatever the pill. */
    fun calendar(now: Instant = Instant.now()) = ReleaseCalendar(releases, now)

    /** More moves to fetch while the oldest loaded still falls in the feed's thirty days. */
    val hasMore: Boolean
        get() {
            val oldest = events.minOfOrNull { it.at } ?: return false
            if (!moreOnServer) return false
            val since = Instant.now().atZone(ZoneId.systemDefault()).minusDays(NewsFeedLayout.RELEASED_DAYS).toInstant()
            return oldest >= since
        }

    val stories: List<FriendStory> get() = NewsFeedLayout.stories(events, ringsSeenAt)

    // Loading

    /** Each visit lights the rings of who moved since the last one, and lets the cards turned down go. */
    suspend fun loadOnAppear() {
        markFriendsSeen()
        if (wished.turnedDown.isNotEmpty()) {
            dismissed = dismissed + wished.turnedDown
            wished = wished.forgetTurnedDown()
        }
        if (!hasLoaded) load()
    }

    /** The first page and the rest, asked together. Over rows already on screen a failure says nothing. */
    suspend fun load() {
        generation += 1
        val token = generation
        isLoading = !hasLoaded
        val opening = fetchOpening()
        if (token != generation) return
        opening.feed.onSuccess {
            events = it.items
            cursor = it.endCursor
            moreOnServer = it.hasMore
            errorMessage = null
        }
        opening.upcoming.onSuccess { releases = it }
        opening.narratorNews.onSuccess { narratorNews = it }
        opening.yearReleases.onSuccess { yearReleases = it }
        opening.awards.onSuccess { awardSections = it }
        opening.discoveries.onSuccess { suggestions = it }
        opening.wishlist.onSuccess { wishlistReleases = it }
        opening.feed.exceptionOrNull()?.takeIf { !isCancellation(it) }?.let {
            if (events.isEmpty()) errorMessage = it.localizedMessage
            reportError(it)
        }
        listOf(opening.upcoming, opening.narratorNews, opening.yearReleases, opening.awards, opening.discoveries, opening.wishlist)
            .mapNotNull { it.exceptionOrNull() }
            .distinct()
            .filter { it !== opening.feed.exceptionOrNull() && !isCancellation(it) }
            .forEach { reportError(it) }
        hasLoaded = true
        isLoading = false
        if (opening.feed.isSuccess) saveSnapshot()
        loadAlerts()
    }

    suspend fun loadMore() {
        val after = cursor ?: return
        if (!hasMore || isLoadingMore) return
        isLoadingMore = true
        pageFailed = false
        val token = generation
        try {
            val page = client.feed(after, PAGE_SIZE)
            if (token != generation) return
            val known = events.map { it.id }.toSet()
            events = events + page.items.filter { it.id !in known }
            cursor = page.endCursor
            moreOnServer = page.hasMore
        } catch (error: Exception) {
            if (isCancellation(error)) return
            pageFailed = true
            reportError(error)
        } finally {
            isLoadingMore = false
        }
    }

    /** Reached a row near the end of what is loaded. */
    fun prefetchIfNeeded(id: String) {
        val ids = events.map { it.id }
        val index = ids.indexOf(id)
        if (index >= 0 && index >= ids.size - 8) scope.launch { loadMore() }
    }

    suspend fun loadAlerts() {
        alertsSilenced = client.alertsSilenced()
    }

    /** The rings keep what they showed until the next visit. */
    private fun markFriendsSeen() {
        ringsSeenAt = friendsSeenAt
        val now = Instant.now()
        friendsSeenAt = now
        preferences?.edit()?.putLong(FRIENDS_SEEN, now.toEpochMilli())?.apply()
    }

    // A card's "+" and its eye

    /** "+": the book onto the wish list, whatever brought it. */
    suspend fun wish(card: NewsCard) {
        when (card) {
            is NewsCard.Friend -> wish(card.key) { it.wishFriendBook(card.move.lead.friendId, card.move.lead.bookId) }
            is NewsCard.Released -> wish(card.key) { it.wishReleased(card.item.draft) }
            is NewsCard.Upcoming -> {
                val draft = ReleasedItem.Release(card.release, java.time.LocalDate.now()).draft
                wish(card.key) { it.wishReleased(draft) }
            }
            is NewsCard.Discovery -> {
                val draft = card.suggestion.draft.copy(coverURL = card.suggestion.coverURL)
                wish(card.key) { it.wishDiscovery(draft, Wish.Origin.DISCOVERY) }
            }
            is NewsCard.Award -> {
                val draft = card.winner.draft.copy(coverURL = card.winner.coverURL)
                wish(card.key) { it.wishDiscovery(draft, Wish.Origin.AWARD) }
            }
        }
    }

    /** Shown wished at once; back if the server refused. The wish's id is kept for a second tap. */
    private suspend fun wish(key: String, write: suspend (NewsClient) -> String) {
        wished = wished.insert(key)
        var wishId: String? = null
        if (perform { wishId = write(client) }) {
            wishId?.let { wishIds[key] = it }
        } else {
            wished = wished.remove(key)
        }
    }

    /**
     * A second tap on the wished "Envies": the wish made here is taken back, an edition of the
     * wish list's rail stops being awaited. Back again if the server refused.
     */
    suspend fun unwish(card: NewsCard) {
        val key = card.key
        val wishId = wishIds[key]
        val editionId = card.awaitedEditionId
        if (wishId != null) {
            wished = wished.remove(key)
            if (perform { client.removeWish(wishId) }) wishIds.remove(key) else wished = wished.insert(key)
        } else if (editionId != null) {
            wished = wished.drop(key)
            if (!perform { client.stopAwaiting(editionId) }) wished = wished.restore(key)
        }
    }

    /** "Pas intéressé" from a card's eye: black and white at once, back in colour if refused. */
    suspend fun dismiss(card: NewsCard) {
        val write: suspend () -> Unit = when (card) {
            is NewsCard.Discovery -> ({ client.dismissSuggestion(card.suggestion.id) })
            is NewsCard.Award -> card.winner.key?.let { key -> { client.dismissWinner(key) } } ?: return
            else -> return
        }
        wished = wished.turnDown(card.key)
        if (!perform(write)) wished = wished.reconsider(card.key)
    }

    /** The eye pressed again, or the greyed "+ Ajouter": back in colour and kept. */
    suspend fun reconsider(card: NewsCard) {
        val write: suspend () -> Unit = when (card) {
            is NewsCard.Discovery -> ({ client.reconsiderSuggestion(card.suggestion.id) })
            is NewsCard.Award -> card.winner.key?.let { key -> { client.reconsiderWinner(key) } } ?: return
            else -> return
        }
        wished = wished.reconsider(card.key)
        if (!perform(write)) wished = wished.turnDown(card.key)
    }

    /** "+ Ajouter": onto the pile or among the books read, in the format chosen. Its capsule says it. */
    suspend fun add(card: NewsCard, status: CopiedStatus, format: BookFormat) {
        val reading = if (status == CopiedStatus.READ) ReadingStatus.READ else ReadingStatus.TO_READ
        val add: suspend () -> String = when (card) {
            is NewsCard.Friend -> ({ client.addFriendBook(card.move.lead.friendId, card.move.lead.bookId, status, format) })
            is NewsCard.Released -> card.item.draft.taken(format, reading).let { draft -> { client.addReleased(draft) } }
            is NewsCard.Upcoming -> ReleasedItem.Release(card.release, java.time.LocalDate.now()).draft.taken(format, reading).let { draft -> { client.addReleased(draft) } }
            is NewsCard.Discovery -> card.suggestion.draft.copy(coverURL = card.suggestion.coverURL).taken(format, reading).let { draft -> { client.addReleased(draft) } }
            is NewsCard.Award -> card.winner.draft.copy(coverURL = card.winner.coverURL).taken(format, reading).let { draft -> { client.addReleased(draft) } }
        }
        var bookId: String? = null
        if (perform { bookId = add() }) {
            bookId?.let { bookIds[card.key] = it }
            val isAudio = format == BookFormat.AUDIOBOOK
            wished = wished.did(if (status == CopiedStatus.READ) TakenState.Read(isAudio) else TakenState.ToRead(isAudio), card.key)
            if (card is NewsCard.Friend) taken = taken + card.key
        }
    }

    /** "+ Ajouter": an edition in the phone's language awaited. Its capsule then says which. */
    suspend fun awaitEdition(card: NewsCard, format: ReleaseFormat) {
        val write: suspend () -> String = when (card) {
            is NewsCard.Friend -> ({ client.awaitFriendBook(card.move.lead.friendId, card.move.lead.bookId, format) })
            is NewsCard.Released -> ({ client.awaitReleased(card.item.draft, format) })
            is NewsCard.Upcoming -> ReleasedItem.Release(card.release, java.time.LocalDate.now()).draft.let { draft -> { client.awaitReleased(draft, format) } }
            is NewsCard.Discovery -> ({ client.awaitReleased(card.suggestion.draft, format) })
            is NewsCard.Award -> ({ client.awaitReleased(card.winner.draft, format) })
        }
        var editionId: String? = null
        if (perform { editionId = write() }) {
            editionId?.let { editionIds[card.key] = it }
            wished = wished.did(TakenState.Awaited(format), card.key)
        }
    }

    /** A card's capsule pressed: what its "+ Ajouter" did is taken back, and "+ Ajouter" comes back. */
    suspend fun undo(card: NewsCard, isWished: Boolean) {
        val key = card.key
        when (wished.state(card, isWished)) {
            TakenState.Wished -> unwish(card)
            is TakenState.ToRead, is TakenState.Read -> {
                val bookId = bookIds[key] ?: return
                if (perform { client.deleteBook(bookId) }) {
                    bookIds.remove(key)
                    wished = wished.did(null, key)
                }
            }
            is TakenState.Awaited -> {
                val editionId = editionIds[key] ?: return
                if (perform { client.stopAwaiting(editionId) }) {
                    editionIds.remove(key)
                    wished = wished.did(null, key)
                }
            }
            TakenState.Owned, null -> Unit
        }
    }

    /** Runs a write, reporting a failure. True once it went through. */
    private suspend fun perform(write: suspend () -> Unit): Boolean = try {
        write()
        true
    } catch (error: Exception) {
        if (!isCancellation(error)) reportError(error)
        false
    }

    private fun saveSnapshot() {
        val cache = cache ?: return
        val snapshot = Snapshot(events.take(PAGE_SIZE), releases, yearReleases, narratorNews, awardSections, suggestions, wishlistReleases)
        scope.launch(Dispatchers.IO) { cache.write(snapshot) }
    }

    /** Every section of the opening, each told apart as answered or failed. */
    private class Opening(
        val feed: Result<CursorPage<FeedEvent>>,
        val upcoming: Result<List<UpcomingRelease>>,
        val narratorNews: Result<List<NarratorNews>>,
        val yearReleases: Result<List<UpcomingRelease>>,
        val awards: Result<List<AwardSection>>,
        val discoveries: Result<List<Suggestion>>,
        val wishlist: Result<List<UpcomingRelease>>,
    )

    /**
     * The opening in one request, which reads the library once for every section. Should a field
     * come back in error, each section is asked alone: the one that fails keeps what it showed.
     */
    private suspend fun fetchOpening(): Opening {
        client.opening?.let { opening ->
            val found = runCatching { opening(PAGE_SIZE) }
            found.onSuccess {
                return Opening(
                    Result.success(it.feed), Result.success(it.upcoming), Result.success(it.narratorNews),
                    Result.success(it.yearReleases), Result.success(it.awards), Result.success(it.discoveries),
                    Result.success(it.wishlistReleases),
                )
            }
            val error = found.exceptionOrNull()!!
            if (!answeredWithErrors(error)) {
                return Opening(Result.failure(error), Result.failure(error), Result.failure(error), Result.failure(error), Result.failure(error), Result.failure(error), Result.failure(error))
            }
        }
        return coroutineScope {
            val page = async { runCatching { client.feed(null, PAGE_SIZE) } }
            val upcoming = async { runCatching { client.upcoming() } }
            val narrated = async { runCatching { client.narratorNews() } }
            val released = async { runCatching { client.yearReleases() } }
            val prizes = async { runCatching { client.awards() } }
            val picks = async { runCatching { client.discoveries() } }
            val wishlist = async { runCatching { client.wishlistReleases() } }
            Opening(page.await(), upcoming.await(), narrated.await(), released.await(), prizes.await(), picks.await(), wishlist.await())
        }
    }

    /** The server answered, with an error on one field: each section is worth asking alone. */
    private fun answeredWithErrors(error: Throwable) = error is ApiError.GraphQL || error is ApiError.Domain

    companion object {
        const val PAGE_SIZE = 20
        private const val FRIENDS_SEEN = "news.friendsSeenAt"
    }
}

/** The book taken in the format chosen, on the shelf it goes to. */
internal fun BookDraft.taken(format: BookFormat, status: ReadingStatus): BookDraft = copy(
    format = format,
    media = if (format == BookFormat.AUDIOBOOK) emptyList() else media.ifEmpty { listOf(BookMedium.PRINT) },
    status = status,
)
