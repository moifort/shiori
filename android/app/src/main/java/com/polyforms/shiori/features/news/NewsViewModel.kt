package com.polyforms.shiori.features.news

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.friends.FriendInvitation
import com.polyforms.shiori.features.friends.FriendsApi
import com.polyforms.shiori.features.settings.NotificationsApi
import com.polyforms.shiori.features.wishlist.Wish
import com.polyforms.shiori.features.wishlist.WishlistApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.CursorPage
import com.polyforms.shiori.shared.NotificationAuthorization
import com.polyforms.shiori.shared.PushRegistrar
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SnapshotCache
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

/** What the News asks of the server. */
interface NewsClient {
    suspend fun feed(after: String?, limit: Int): CursorPage<FeedEvent>
    suspend fun upcoming(): List<UpcomingRelease>
    suspend fun yearReleases(): List<UpcomingRelease>
    suspend fun narratorNews(): List<NarratorNews>
    suspend fun addFriendBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat)
    suspend fun wishFriendBook(friendId: String, bookId: String)
    suspend fun awaitFriendBook(friendId: String, bookId: String, format: ReleaseFormat)
    suspend fun addReleased(draft: BookDraft)
    suspend fun wishReleased(draft: BookDraft)
    suspend fun awaitReleased(draft: BookDraft, format: ReleaseFormat)
    suspend fun alertsSilenced(): Boolean
    suspend fun invite(): FriendInvitation

    companion object {
        val live: NewsClient = object : NewsClient {
            override suspend fun feed(after: String?, limit: Int) = NewsApi.feed(after, limit)
            override suspend fun upcoming() = NewsApi.upcoming()
            override suspend fun yearReleases() = NewsApi.yearReleases()
            override suspend fun narratorNews() = NewsApi.narratorNews()
            override suspend fun addFriendBook(friendId: String, bookId: String, status: CopiedStatus, format: BookFormat) {
                FriendsApi.addBook(friendId, bookId, status, format)
            }
            override suspend fun wishFriendBook(friendId: String, bookId: String) {
                WishlistApi.wish(friendId, bookId)
            }
            override suspend fun awaitFriendBook(friendId: String, bookId: String, format: ReleaseFormat) {
                AwaitedApi.awaitEdition(friendId, bookId, format)
            }
            override suspend fun addReleased(draft: BookDraft) {
                BookAddition.add(draft, source = AnalyticsEvent.BookSource.DISCOVER)
            }
            override suspend fun wishReleased(draft: BookDraft) {
                WishlistApi.wish(draft, Wish.Origin.DISCOVERY)
            }
            override suspend fun awaitReleased(draft: BookDraft, format: ReleaseFormat) {
                AwaitedApi.awaitScanned(draft, format)
            }
            override suspend fun alertsSilenced(): Boolean {
                val denied = PushRegistrar.authorization() == NotificationAuthorization.DENIED
                val settings = runCatching { NotificationsApi.settings() }.getOrNull()
                return denied || settings?.enabled?.isEmpty() == true
            }
            override suspend fun invite() = FriendsApi.invite()
        }
    }
}

/** The News tab: friends' moves, what came out, what is coming, the stories rail. */
class NewsViewModel(private val client: NewsClient, private val scope: CoroutineScope, caching: Boolean = true) {
    @Serializable
    private data class Snapshot(val events: List<FeedEvent>, val releases: List<UpcomingRelease>, val yearReleases: List<UpcomingRelease>, val narratorNews: List<NarratorNews>)

    private val cache = if (caching) SnapshotCache("news", 3, Snapshot.serializer()) else null
    private val preferences = AppContext.get().getSharedPreferences("shiori", Context.MODE_PRIVATE)

    var events by mutableStateOf<List<FeedEvent>>(emptyList())
        private set
    var releases by mutableStateOf<List<UpcomingRelease>>(emptyList())
        private set
    var yearReleases by mutableStateOf<List<UpcomingRelease>>(emptyList())
        private set
    var narratorNews by mutableStateOf<List<NarratorNews>>(emptyList())
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
    var taken by mutableStateOf(emptySet<String>())
        private set
    var wished by mutableStateOf(emptySet<String>())
        private set
    var awaited by mutableStateOf(emptySet<String>())
        private set
    var alertsSilenced by mutableStateOf(false)
        private set
    var invitation by mutableStateOf<FriendInvitation?>(null)
    var format by mutableStateOf<BookFormat?>(null)
    var friendId by mutableStateOf<String?>(null)
    private var moreOnServer = false
    private var cursor: String? = null
    private var generation = 0
    private var friendsSeenAt: Instant? = preferences.getLong(FRIENDS_SEEN, 0).takeIf { it > 0 }?.let(Instant::ofEpochMilli)
    private var ringsSeenAt = friendsSeenAt

    init {
        cache?.read()?.let {
            events = it.events
            releases = it.releases
            yearReleases = it.yearReleases
            narratorNews = it.narratorNews
        }
    }

    private val shownEvents: List<FeedEvent> get() = events.map { if (it.bookId in taken) it.copy(inLibrary = true) else it }

    fun released(now: Instant = Instant.now()) = NewsFeedLayout.released(yearReleases, narratorNews, format, now)
    fun feedSections(now: Instant = Instant.now()) = NewsFeedLayout.feedSections(released(now), shownEvents, format, friendId, now)
    fun pillFormats(now: Instant = Instant.now()): List<BookFormat> {
        val everything = NewsFeedLayout.feedSections(NewsFeedLayout.released(yearReleases, narratorNews, null, now), shownEvents, null, friendId, now)
        return NewsFeedLayout.pillFormats(everything, format)
    }
    fun calendar(now: Instant = Instant.now()) = ReleaseCalendar(releases, now)

    val hasMore: Boolean
        get() {
            val oldest = events.minOfOrNull { it.at } ?: return false
            if (!moreOnServer) return false
            val since = Instant.now().atZone(ZoneId.systemDefault()).minusDays(NewsFeedLayout.RELEASED_DAYS).toInstant()
            return oldest >= since
        }

    val stories: List<FriendStory> get() = NewsFeedLayout.stories(events, ringsSeenAt)

    suspend fun loadOnAppear() {
        markFriendsSeen()
        if (!hasLoaded) load()
    }

    suspend fun load() = coroutineScope {
        generation += 1
        val token = generation
        isLoading = !hasLoaded
        val page = async { runCatching { client.feed(null, PAGE_SIZE) } }
        val upcoming = async { runCatching { client.upcoming() } }
        val voices = async { runCatching { client.narratorNews() } }
        val year = async { runCatching { client.yearReleases() } }
        val first = page.await()
        val dated = upcoming.await()
        val narrated = voices.await()
        val released = year.await()
        if (token != generation) return@coroutineScope
        first.onSuccess {
            events = it.items
            cursor = it.endCursor
            moreOnServer = it.hasMore
            errorMessage = null
        }
        dated.onSuccess { releases = it }
        narrated.onSuccess { narratorNews = it }
        released.onSuccess { yearReleases = it }
        first.exceptionOrNull()?.takeIf { it is Exception && !isCancellation(it) }?.let {
            if (events.isEmpty()) errorMessage = it.localizedMessage
            reportError(it)
        }
        listOf(dated, released).forEach { result -> result.exceptionOrNull()?.takeIf { !isCancellation(it) }?.let { reportError(it) } }
        hasLoaded = true
        isLoading = false
        if (first.isSuccess) cache?.let { cache ->
            val snapshot = Snapshot(events.take(PAGE_SIZE), releases, yearReleases, narratorNews)
            scope.launch(Dispatchers.IO) { cache.write(snapshot) }
        }
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

    fun prefetchIfNeeded(id: String) {
        val ids = events.map { it.id }
        val index = ids.indexOf(id)
        if (index >= 0 && index >= ids.size - 8) scope.launch { loadMore() }
    }

    suspend fun loadAlerts() {
        alertsSilenced = client.alertsSilenced()
    }

    private fun markFriendsSeen() {
        ringsSeenAt = friendsSeenAt
        val now = Instant.now()
        friendsSeenAt = now
        preferences.edit().putLong(FRIENDS_SEEN, now.toEpochMilli()).apply()
    }

    private suspend fun perform(write: suspend () -> Unit): Boolean = try {
        write()
        true
    } catch (error: Exception) {
        if (!isCancellation(error)) reportError(error)
        false
    }

    suspend fun add(event: FeedEvent, status: CopiedStatus, format: BookFormat) {
        if (perform { client.addFriendBook(event.friendId, event.bookId, status, format) }) taken = taken + event.bookId
    }

    suspend fun wish(event: FeedEvent) {
        if (perform { client.wishFriendBook(event.friendId, event.bookId) }) wished = wished + event.bookId
    }

    suspend fun awaitEdition(event: FeedEvent, format: ReleaseFormat) {
        awaited = awaited + event.bookId
        if (!perform { client.awaitFriendBook(event.friendId, event.bookId, format) }) awaited = awaited - event.bookId
    }

    suspend fun add(item: ReleasedItem, status: CopiedStatus, format: BookFormat) {
        val draft = item.draft.copy(
            format = format,
            media = if (format == BookFormat.AUDIOBOOK) emptyList() else listOf(BookMedium.PRINT),
            status = if (status == CopiedStatus.READ) ReadingStatus.READ else ReadingStatus.TO_READ,
        )
        if (perform { client.addReleased(draft) }) taken = taken + item.id
    }

    suspend fun wish(item: ReleasedItem) {
        if (perform { client.wishReleased(item.draft) }) wished = wished + item.id
    }

    suspend fun awaitEdition(item: ReleasedItem, format: ReleaseFormat) {
        awaited = awaited + item.id
        if (!perform { client.awaitReleased(item.draft, format) }) awaited = awaited - item.id
    }

    suspend fun invite() {
        try {
            invitation = client.invite()
        } catch (error: Exception) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    companion object {
        const val PAGE_SIZE = 20
        private const val FRIENDS_SEEN = "news.friendsSeenAt"
    }
}

