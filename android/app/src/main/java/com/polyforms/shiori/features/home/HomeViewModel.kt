package com.polyforms.shiori.features.home

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.DismissalReason
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.organisms.taken
import com.polyforms.shiori.features.discover.shelfDraft
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import java.text.Collator
import java.time.Instant
import java.time.LocalDate

/** The Home: the dashboard, the releases of the week, the month's discoveries. */
class HomeViewModel(
    private val client: HomeClient,
    private val scope: CoroutineScope,
    caching: Boolean = true,
    private val seenStore: SeenReleases = SeenReleases(),
) {
    private val cache = if (caching) SnapshotCache("dashboard", 5, Dashboard.serializer()) else null
    private val releasesCache = if (caching) SnapshotCache("dashboard-releases", 3, ListSerializer(HomeRelease.serializer())) else null
    private val discoveriesCache = if (caching) SnapshotCache("dashboard-discoveries", 3, MonthlyDiscoveries.serializer()) else null

    var dashboard by mutableStateOf(cache?.read())
        private set
    var releases by mutableStateOf(releasesCache?.read() ?: emptyList())
        private set
    var discoveries by mutableStateOf(discoveriesCache?.read())
        private set
    var isLookingUpDiscoveries by mutableStateOf(false)
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var actionError by mutableStateOf<String?>(null)

    /** What the hero asks the reader to set up, as the server last said. */
    var prompts by mutableStateOf(emptyList<HomePrompt>())
        private set
    /** The prompts turned down since the page opened: kept on screen, their eye filled, until the reader leaves. */
    private var heldPrompts by mutableStateOf(emptySet<HomePrompt>())
    /** The prompts turned down here, until the server's next answer says so. */
    private var dismissedPrompts by mutableStateOf(emptySet<HomePrompt>())

    /**
     * The one prompt the hero shows, after its other pages: the first the reader has not turned
     * down, or the one just turned down while the page is open. Never before the first book: the
     * empty shelf offers the same in its own rows.
     */
    val shownPrompt: HomePrompt?
        get() {
            if (dashboard?.libraryIsEmpty != false) return null
            return prompts.firstOrNull { it !in dismissedPrompts || it in heldPrompts }
        }

    private var seenReleases by mutableStateOf(seenStore.all)
    private var heldReleases by mutableStateOf(emptySet<String>())
    val hiddenReleases: Set<String> get() = seenReleases - heldReleases

    val isSearchingDiscoveries: Boolean
        get() = isLookingUpDiscoveries || (discoveries?.month == MonthlyDiscoveries.month(Instant.now()) && discoveries?.status == MonthlyDiscoveries.Status.SEARCHING)

    val discoveryChoices = DiscoveryChoices()
    private val taken = mutableListOf<Suggestion>()
    private val booksRead = mutableMapOf<String, String>()
    /** The wishes made from a discovery, which "Envies" on its page takes back. */
    private val wishIds = mutableMapOf<String, String>()
    /** The books put on the pile from a discovery, and the editions awaited from one. */
    private val booksAdded = mutableMapOf<String, String>()
    private val awaitedIds = mutableMapOf<String, MutableMap<ReleaseFormat, String>>()
    private var loaded = false
    private var discoveriesRead = false
    private var loading: Deferred<Unit>? = null
    private var reloadAsked = false

    suspend fun load() {
        loading?.let {
            reloadAsked = true
            it.await()
            return
        }
        isLoading = true
        val task = scope.async {
            do {
                reloadAsked = false
                refresh()
            } while (reloadAsked)
        }
        loading = task
        try {
            task.await()
        } finally {
            loading = null
            isLoading = false
        }
    }

    private suspend fun refresh() = coroutineScope {
        errorMessage = null
        val fetchedReleases = async { fetchReleases() }
        try {
            val fetched = fetchTop()
            dashboard = fetched
            loaded = true
            cache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
            scope.launch { lookUpDiscoveriesIfDue() }
        } catch (error: Exception) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
        keep(fetchedReleases.await())
    }

    /**
     * The dashboard, with the month's discoveries and the hero's prompts in the same request.
     * Should it fail, each is asked alone: the discoveries apart, never in the figures' way.
     */
    private suspend fun fetchTop(): Dashboard = coroutineScope {
        val top = try {
            client.opening()
        } catch (error: Exception) {
            if (isCancellation(error)) throw error
            null
        }
        if (top != null) {
            discoveriesRead = true
            show(top.discoveries)
            prompts = top.prompts
            return@coroutineScope top.dashboard
        }
        scope.launch { loadDiscoveries() }
        client.dashboard()
    }

    private fun keep(fetched: List<HomeRelease>?) {
        fetched ?: return
        releases = fetched
        releasesCache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
    }

    suspend fun loadDiscoveries() {
        val found = runCatching { client.discoveries() }.getOrNull() ?: return
        discoveriesRead = true
        show(found)
        lookUpDiscoveriesIfDue()
    }

    private suspend fun lookUpDiscoveriesIfDue() {
        val board = dashboard ?: return
        if (isLookingUpDiscoveries || !discoveriesRead || board.libraryIsEmpty || !selectionIsDue(discoveries)) return
        isLookingUpDiscoveries = true
        try {
            var failures = 0
            repeat(SEARCH_POLLS) {
                try {
                    val found = client.lookUpDiscoveries()
                    show(found)
                    if (found.status != MonthlyDiscoveries.Status.SEARCHING) return
                } catch (error: Exception) {
                    if (isCancellation(error)) return
                    failures += 1
                    if (failures >= 3) return
                }
                delay(SEARCH_POLL_MILLIS)
            }
        } finally {
            isLookingUpDiscoveries = false
        }
    }

    private fun show(found: MonthlyDiscoveries) {
        discoveries = keepingTaken(found)
        discoveriesCache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(found) } }
    }

    private fun hold(suggestion: Suggestion) {
        if (taken.none { it.id == suggestion.id }) taken += suggestion
    }

    suspend fun releaseTaken() {
        heldReleases = emptySet()
        heldPrompts = emptySet()
        if (taken.isEmpty()) return
        taken.clear()
        loadDiscoveries()
    }

    fun see(release: HomeRelease) {
        heldReleases = heldReleases + release.id
        seenReleases = seenReleases + release.id
        seenStore.see(release.id)
    }

    /** A prompt turned down from the hero's closed eye: kept on the account, and on screen until the reader leaves. */
    fun dismiss(prompt: HomePrompt) {
        heldPrompts = heldPrompts + prompt
        dismissedPrompts = dismissedPrompts + prompt
        scope.launch { send(prompt, dismissed = true) }
    }

    /** The eye pressed again: the prompt is asked again. */
    fun undismiss(prompt: HomePrompt) {
        dismissedPrompts = dismissedPrompts - prompt
        scope.launch { send(prompt, dismissed = false) }
    }

    /** Tells the server, which keeps the answer for every device. A failure puts the prompt back as it stood. */
    private suspend fun send(prompt: HomePrompt, dismissed: Boolean) {
        try {
            client.dismissPrompt(prompt, dismissed)
        } catch (error: Exception) {
            if (isCancellation(error)) return
            dismissedPrompts = if (dismissed) dismissedPrompts - prompt else dismissedPrompts + prompt
        }
    }

    fun unsee(release: HomeRelease) {
        seenReleases = seenReleases - release.id
        seenStore.unsee(release.id)
    }

    private fun keepingTaken(found: MonthlyDiscoveries): MonthlyDiscoveries {
        val shown = discoveries?.suggestions
        if (taken.isEmpty() || shown == null) return found
        val suggestions = found.suggestions.toMutableList()
        for (suggestion in taken) {
            if (suggestions.any { it.id == suggestion.id }) continue
            val index = shown.indexOfFirst { it.id == suggestion.id }.takeIf { it >= 0 } ?: suggestions.size
            suggestions.add(minOf(index, suggestions.size), suggestion)
        }
        return found.copy(suggestions = suggestions)
    }

    suspend fun reloadReleases() = keep(fetchReleases())

    /** The month's last releases and the coming ones, of the sagas followed and the editions awaited. */
    private suspend fun fetchReleases(): List<HomeRelease>? = coroutineScope {
        val books = async { runCatching { client.discovery(ReleaseFormat.BOOK) }.getOrNull() }
        val audiobooks = async { runCatching { client.discovery(ReleaseFormat.AUDIOBOOK) }.getOrNull() }
        val recordings = async { runCatching { client.awaited(ReleaseFormat.AUDIOBOOK) }.getOrNull() }
        val translations = async { runCatching { client.awaited(ReleaseFormat.BOOK) }.getOrNull() }
        val bookPage = books.await() ?: return@coroutineScope null
        val audioPage = audiobooks.await() ?: return@coroutineScope null
        val rows = bookPage.rows + audioPage.rows
        val awaited = (recordings.await() ?: emptyList()) + (translations.await() ?: emptyList())
        val collator = Collator.getInstance()
        val recentVolumes = rows.flatMap { saga -> saga.recent.map { HomeRelease.Volume(DiscoveryVolume(saga, it)) } }
        val since = LocalDate.now().minusDays(RECENT_DAYS).toString()
        val recentAwaited = awaited
            .filter { edition -> edition.state == AwaitedState.AVAILABLE && edition.date?.let { it.length == 10 && it >= since } == true }
            .map { HomeRelease.Awaited(it) }
        val recent = (recentVolumes + recentAwaited).sortedWith { a, b ->
            val byDate = (b.date ?: "").compareTo(a.date ?: "")
            if (byDate != 0) byDate else collator.compare(a.name, b.name)
        }
        val nextVolumes = rows.mapNotNull { row -> row.releases.next?.let { HomeRelease.Volume(DiscoveryVolume(row, it)) } }
        val awaitedComing = awaited.filter { it.state == AwaitedState.ANNOUNCED }.map { HomeRelease.Awaited(it) }
        val today = LocalDate.now().toString()
        val upcoming = (nextVolumes + awaitedComing)
            .mapNotNull { release ->
                val date = release.date ?: return@mapNotNull null
                if (date == today || ReleaseDateText.isUpcoming(date)) release to ReleaseDateText.lastDay(date) else null
            }
            .sortedWith { a, b -> if (a.second != b.second) a.second.compareTo(b.second) else collator.compare(a.first.name, b.first.name) }
            .map { it.first }
        (recent + upcoming).take(RELEASES_SHOWN)
    }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    suspend fun choose(suggestion: Suggestion, choice: DiscoveryChoice): Boolean {
        hold(suggestion)
        return try {
            when (choice) {
                is DiscoveryChoice.Add -> booksAdded[suggestion.id] = client.addBook(suggestion.shelfDraft(ReadingStatus.TO_READ).taken(choice.format, ReadingStatus.TO_READ))
                is DiscoveryChoice.Await -> awaitedIds.getOrPut(suggestion.id) { mutableMapOf() }[choice.format] = client.awaitEdition(suggestion.draft, choice.format)
                is DiscoveryChoice.AlreadyRead -> booksRead[suggestion.id] = client.addBook(suggestion.shelfDraft(ReadingStatus.READ).taken(choice.format, ReadingStatus.READ))
                DiscoveryChoice.Wish -> wishIds[suggestion.id] = client.wish(suggestion.shelfDraft(ReadingStatus.TO_READ))
                DiscoveryChoice.Unwish -> {
                    wishIds[suggestion.id]?.let { client.removeWish(it) }
                    wishIds.remove(suggestion.id)
                }
                DiscoveryChoice.UndoAdd -> {
                    booksAdded[suggestion.id]?.let { client.deleteBook(it) }
                    booksAdded.remove(suggestion.id)
                }
                is DiscoveryChoice.Unawait -> {
                    // Awaited here, or already when the line was read.
                    val id = awaitedIds[suggestion.id]?.get(choice.format) ?: if (suggestion.format == choice.format) suggestion.awaitedEditionId else null
                    id?.let { client.stopAwaiting(it) }
                    awaitedIds[suggestion.id]?.remove(choice.format)
                }
                DiscoveryChoice.UndoAlreadyRead -> {
                    booksRead[suggestion.id]?.let { client.deleteBook(it) }
                    booksRead.remove(suggestion.id)
                }
                // Black and white on the hero, held there until the reader leaves the page, when
                // it leaves the line (`releaseTaken`).
                DiscoveryChoice.NotInterested -> client.dismissSuggestion(suggestion.id, DismissalReason.NOT_INTERESTED)
                DiscoveryChoice.Reconsider -> client.reconsiderSuggestion(suggestion.id)
            }
            true
        } catch (error: Exception) {
            actionError = reportError(error)
            false
        }
    }

    suspend fun stopAwaiting(edition: AwaitedEdition) {
        try {
            client.stopAwaiting(edition.id)
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun finish(book: Book) {
        try {
            client.finish(book.id)
        } catch (error: Exception) {
            actionError = reportError(error)
        }
    }

    suspend fun recordPage(book: Book, page: Int?, status: ReadingStatus?): String? = try {
        client.recordPage(book.id, page, status)
        null
    } catch (error: Exception) {
        reportError(error)
    }

    suspend fun rate(book: Book, stars: Double) {
        try {
            client.rate(book.id, stars)
        } catch (error: Exception) {
            actionError = reportError(error)
        }
    }

    suspend fun genreInsights(): GenreInsights = client.genreInsights()

    companion object {
        private const val SEARCH_POLL_MILLIS = 5_000L
        private const val SEARCH_POLLS = 40
        private const val RELEASES_SHOWN = 10
        private const val RECENT_DAYS = 30L

        fun selectionIsDue(discoveries: MonthlyDiscoveries?, now: Instant = Instant.now()): Boolean {
            if (discoveries == null || discoveries.month != MonthlyDiscoveries.month(now)) return true
            return discoveries.status != MonthlyDiscoveries.Status.READY
        }
    }
}

/** The discoveries the Home shows: the month's, once chosen. */
val MonthlyDiscoveries.shownOnHome: List<Suggestion> get() = if (status == MonthlyDiscoveries.Status.READY) suggestions else emptyList()

fun MonthlyDiscoveries.doneMonth(today: Instant = Instant.now()): String? =
    if (status == MonthlyDiscoveries.Status.READY && suggestions.isEmpty() && month == MonthlyDiscoveries.month(today)) month else null

val MonthlyDiscoveries.needsRatingsMonth: String? get() = if (needsRatings && status != MonthlyDiscoveries.Status.READY) month else null

/** The first cover the Home can wash its hero with. */
val Dashboard.leadCoverURL: String? get() = (reading + toRead + listOfNotNull(lastFinished)).firstNotNullOfOrNull { it.coverURL }
