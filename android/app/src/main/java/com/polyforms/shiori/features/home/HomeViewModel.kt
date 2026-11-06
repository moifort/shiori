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

    private var seenReleases by mutableStateOf(seenStore.all)
    private var heldReleases by mutableStateOf(emptySet<String>())
    val hiddenReleases: Set<String> get() = seenReleases - heldReleases

    val isSearchingDiscoveries: Boolean
        get() = isLookingUpDiscoveries || (discoveries?.month == MonthlyDiscoveries.month(Instant.now()) && discoveries?.status == MonthlyDiscoveries.Status.SEARCHING)

    val discoveryChoices = DiscoveryChoices()
    private val taken = mutableListOf<Suggestion>()
    private val booksRead = mutableMapOf<String, String>()
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
        launch { loadDiscoveries() }
        val fetchedReleases = async { fetchReleases() }
        try {
            val fetched = client.dashboard()
            dashboard = fetched
            loaded = true
            cache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(fetched) } }
            scope.launch { lookUpDiscoveriesIfDue() }
        } catch (error: Exception) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
        keep(fetchedReleases.await())
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
        if (taken.isEmpty()) return
        taken.clear()
        loadDiscoveries()
    }

    fun see(release: HomeRelease) {
        heldReleases = heldReleases + release.id
        seenReleases = seenReleases + release.id
        seenStore.see(release.id)
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
            .filter { it.state == AwaitedState.AVAILABLE && it.date?.length == 10 && it.date >= since }
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
                DiscoveryChoice.Add -> client.addBook(suggestion.shelfDraft(ReadingStatus.TO_READ))
                is DiscoveryChoice.Await -> client.awaitEdition(suggestion.draft, choice.format)
                DiscoveryChoice.AlreadyRead -> booksRead[suggestion.id] = client.addBook(suggestion.shelfDraft(ReadingStatus.READ))
                DiscoveryChoice.Wish -> client.wish(suggestion.shelfDraft(ReadingStatus.TO_READ))
                DiscoveryChoice.UndoAlreadyRead -> {
                    booksRead[suggestion.id]?.let { client.deleteBook(it) }
                    booksRead.remove(suggestion.id)
                }
                DiscoveryChoice.NotInterested -> {
                    client.dismissSuggestion(suggestion.id, DismissalReason.NOT_INTERESTED)
                    loadDiscoveries()
                }
                DiscoveryChoice.Reconsider -> {
                    client.reconsiderSuggestion(suggestion.id)
                    loadDiscoveries()
                }
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
