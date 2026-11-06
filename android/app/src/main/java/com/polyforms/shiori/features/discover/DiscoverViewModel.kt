package com.polyforms.shiori.features.discover

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.friends.FriendPicks
import com.polyforms.shiori.features.friends.FriendsApi
import com.polyforms.shiori.features.settings.NotificationsApi
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.NotificationAuthorization
import com.polyforms.shiori.shared.PushRegistrar
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.MapSerializer
import java.time.Instant

/** Everything Découvrir asks of the server. */
interface DiscoverClient {
    suspend fun discovery(format: ReleaseFormat): DiscoveryPage
    /** The first look at a format: everything followed in it looked up on the web. */
    suspend fun lookUp(format: ReleaseFormat): DiscoveryPage
    suspend fun picks(): FriendPicks
    suspend fun awaited(format: ReleaseFormat): List<AwaitedEdition>
    suspend fun stopAwaiting(editionId: String)
    suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat): AwaitedEdition
    suspend fun awards(format: ReleaseFormat): List<AwardSection>
    /** The month's discoveries, the selection made when the month has none. */
    suspend fun discoveries(format: ReleaseFormat): MonthlyDiscoveries
    suspend fun alertsSilenced(): Boolean
    suspend fun requestAlerts()

    companion object {
        val live: DiscoverClient = object : DiscoverClient {
            override suspend fun discovery(format: ReleaseFormat) = DiscoverApi.discovery(format)
            override suspend fun lookUp(format: ReleaseFormat) = DiscoverApi.lookUp(format)
            override suspend fun picks() = FriendsApi.picks()
            override suspend fun awaited(format: ReleaseFormat) = AwaitedApi.awaited(format)
            override suspend fun stopAwaiting(editionId: String) = AwaitedApi.stop(editionId)
            override suspend fun awaitEdition(draft: BookDraft, format: ReleaseFormat) = AwaitedApi.awaitScanned(draft, format)
            override suspend fun awards(format: ReleaseFormat) = AwardsApi.sections(format)
            override suspend fun discoveries(format: ReleaseFormat) = SuggestionsApi.monthly(format, lookUp = true)
            override suspend fun alertsSilenced(): Boolean {
                val denied = PushRegistrar.authorization() == NotificationAuthorization.DENIED
                val settings = runCatching { NotificationsApi.settings() }.getOrNull()
                return denied || settings?.enabled?.isEmpty() == true
            }
            override suspend fun requestAlerts() {
                PushRegistrar.requestPermission()
            }
        }
    }
}

/** What Découvrir's discoveries line draws. */
sealed interface DiscoveriesLine {
    data class Shown(val discoveries: MonthlyDiscoveries) : DiscoveriesLine
    data class Searching(val month: String) : DiscoveriesLine
    data class RanOut(val discoveries: MonthlyDiscoveries) : DiscoveriesLine
}

/**
 * Owns Découvrir's rows, one list per format drawn mixed, and the loads. It opens on everything
 * it last showed — the rows, the friends' picks, the editions awaited — kept on disk, brought up
 * to date silently underneath.
 */
class DiscoverViewModel(private val client: DiscoverClient, private val scope: CoroutineScope, caching: Boolean = true) {
    private sealed interface Section {
        data class Rows(val format: ReleaseFormat) : Section
        data object Picks : Section
        data class Awaited(val format: ReleaseFormat) : Section
        data class Awards(val format: ReleaseFormat) : Section
        data class Discoveries(val format: ReleaseFormat) : Section
    }

    private val feedCache = if (caching) SnapshotCache("discovery", 9, DiscoveryFeed.serializer()) else null
    private val awardsCache = if (caching) SnapshotCache("discover-awards", 1, MapSerializer(ReleaseFormat.serializer(), ListSerializer(AwardSection.serializer()))) else null
    private val discoveriesCache = if (caching) SnapshotCache("discover-discoveries", 3, MonthlyDiscoveries.serializer()) else null

    var feed by mutableStateOf(feedCache?.read() ?: DiscoveryFeed())
        private set
    var awards by mutableStateOf(awardsCache?.read() ?: emptyMap())
        private set
    var discoveries by mutableStateOf(discoveriesCache?.read())
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var isLookingUp by mutableStateOf(false)
        private set
    var isLookingUpDiscoveries by mutableStateOf(false)
        private set
    var alertsSilenced by mutableStateOf(false)
        private set
    private var rowsInFlight by mutableStateOf<Set<ReleaseFormat>>(emptySet())
    val isLoading: Boolean get() = rowsInFlight.isNotEmpty()

    /** The editions a scan asked to await, drawn while the server looks them up. Never on disk. */
    private var pendingAwaited by mutableStateOf<List<AwaitedEdition>>(emptyList())

    /** The edition the strip scrolls to: the one a scan just asked to await. */
    var focusedAwaited by mutableStateOf<String?>(null)
        private set

    private val inFlight = mutableSetOf<Section>()
    private val stale = mutableSetOf<Section>()
    private val answered = mutableSetOf<Section>()
    private val lookedUp = mutableSetOf<ReleaseFormat>()

    val awaitedSoon: List<AwaitedEdition>
        get() = if (pendingAwaited.isEmpty()) feed.awaitedSoon else (feed.awaitedSoon + pendingAwaited).soonOrder

    val awardsFormat: ReleaseFormat get() = feed.awardsFormat
    val shownAwards: List<AwardSection> get() = awards[awardsFormat] ?: emptyList()

    val discoveriesLine: DiscoveriesLine?
        get() {
            val month = MonthlyDiscoveries.month(Instant.now())
            val found = discoveries
            if (found == null || found.month != month) return if (isLookingUpDiscoveries) DiscoveriesLine.Searching(month) else null
            return when (found.status) {
                MonthlyDiscoveries.Status.READY -> if (found.suggestions.isEmpty()) DiscoveriesLine.RanOut(found) else DiscoveriesLine.Shown(found)
                MonthlyDiscoveries.Status.SEARCHING -> DiscoveriesLine.Searching(month)
                MonthlyDiscoveries.Status.NONE -> if (isLookingUpDiscoveries) DiscoveriesLine.Searching(month) else null
            }
        }

    /** One request per section at a time; a call landing meanwhile asks again once it ends. */
    private suspend fun run(section: Section, again: Boolean, fetch: suspend () -> Unit) {
        if (section in inFlight) {
            if (again) stale += section
            return
        }
        inFlight += section
        try {
            do {
                stale -= section
                fetch()
            } while (section in stale)
        } finally {
            inFlight -= section
        }
    }

    private fun markAnswered(section: Section) {
        if (section !in stale) answered += section
    }

    private suspend fun loadIfMissing(section: Section) {
        if (section in answered) return
        run(section, again = false) { fetch(section) }
    }

    private suspend fun fetch(section: Section) = when (section) {
        is Section.Rows -> fetchRows(section.format)
        Section.Picks -> fetchPicks()
        is Section.Awaited -> fetchAwaited(section.format)
        is Section.Awards -> fetchAwards(section.format)
        is Section.Discoveries -> fetchDiscoveries(section.format)
    }

    private suspend fun fetchPicks() {
        try {
            feed = feed.copy(picks = client.picks())
            markAnswered(Section.Picks)
            saveSnapshot()
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    private suspend fun fetchAwaited(format: ReleaseFormat) {
        try {
            feed = feed.copy(awaited = feed.awaited + (format to client.awaited(format)))
            markAnswered(Section.Awaited(format))
            saveSnapshot()
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    private suspend fun fetchAwards(format: ReleaseFormat) {
        try {
            awards = awards + (format to client.awards(format))
            markAnswered(Section.Awards(format))
            val kept = awards
            awardsCache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(kept) } }
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
        }
    }

    /** Asks for the month's discoveries; a selection being made is waited for, every few seconds. */
    private suspend fun fetchDiscoveries(format: ReleaseFormat) {
        isLookingUpDiscoveries = true
        var failures = 0
        try {
            repeat(40) {
                try {
                    val found = client.discoveries(format)
                    discoveries = found
                    if (found.status != MonthlyDiscoveries.Status.SEARCHING) {
                        markAnswered(Section.Discoveries(format))
                        discoveriesCache?.let { cache -> scope.launch(Dispatchers.IO) { cache.write(found) } }
                        return
                    }
                } catch (error: Throwable) {
                    if (isCancellation(error)) throw error
                    failures++
                    if (failures >= 3) {
                        reportError(error)
                        return
                    }
                }
                delay(5_000)
            }
        } finally {
            isLookingUpDiscoveries = false
        }
    }

    private suspend fun fetchRows(format: ReleaseFormat) {
        rowsInFlight = rowsInFlight + format
        errorMessage = null
        val page = try {
            client.discovery(format)
        } catch (error: Throwable) {
            rowsInFlight = rowsInFlight - format
            // The last rows stay on screen and say nothing; a pull tries again.
            if (!isCancellation(error)) errorMessage = reportError(error)
            return
        }
        feed = feed.copy(followed = feed.followed + (format to page.followed))
        show(page, format)
        markAnswered(Section.Rows(format))
        rowsInFlight = rowsInFlight - format
        // The very first look, when nothing followed in this format was ever looked up.
        if (page.followed > 0 && page.unwatched == page.followed && format !in lookedUp) lookUp(format)
        // The system asks once, the first time there is a volume to announce.
        if (feed.rows[format]?.any { it.releases.next != null } == true) client.requestAlerts()
    }

    private suspend fun lookUp(format: ReleaseFormat) {
        lookedUp += format
        isLookingUp = true
        try {
            show(client.lookUp(format), format)
        } catch (error: Throwable) {
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
        isLookingUp = false
    }

    private fun show(page: DiscoveryPage, format: ReleaseFormat) {
        feed = feed.copy(rows = feed.rows + (format to page.rows), authors = feed.authors + (format to page.authors))
        saveSnapshot()
    }

    private fun saveSnapshot() {
        val cache = feedCache ?: return
        val snapshot = feed
        scope.launch(Dispatchers.IO) { cache.write(snapshot) }
    }

    /** The screen appeared: every section never answered loads, each once. */
    suspend fun loadOnAppear() {
        scope.launch { loadAlerts() }
        scope.launch { loadIfMissing(Section.Picks) }
        ReleaseFormat.entries.forEach { format -> scope.launch { loadIfMissing(Section.Awaited(format)) } }
        if (feed.sagas != null) scope.launch { loadShownIfMissing() }
        for (format in ReleaseFormat.entries) loadIfMissing(Section.Rows(format))
        // The rows may have moved the format shown.
        loadShownIfMissing()
    }

    private suspend fun loadShownIfMissing() {
        val format = awardsFormat
        scope.launch { loadIfMissing(Section.Awards(format)) }
        loadIfMissing(Section.Discoveries(format))
    }

    /** A pull: the rows of both formats and the picks, and the format the rows moved to. */
    suspend fun refresh() {
        scope.launch { run(Section.Picks, true) { fetchPicks() } }
        loadAll()
        loadShownIfMissing()
    }

    suspend fun loadAll() {
        for (format in ReleaseFormat.entries) run(Section.Rows(format), true) { fetchRows(format) }
    }

    /** A write landed anywhere: the rows, the picks, the award winners and the discoveries. */
    suspend fun libraryChanged() {
        for (format in ReleaseFormat.entries.filter { Section.Rows(it) in answered }) run(Section.Rows(format), true) { fetchRows(format) }
        run(Section.Picks, true) { fetchPicks() }
        loadShown()
    }

    /** An edition was awaited or given up: the strip and the Authors shelf carry them. */
    suspend fun awaitedChanged() {
        for (format in ReleaseFormat.entries.filter { feed.awaited[it] != null }) run(Section.Awaited(format), true) { fetchAwaited(format) }
        libraryChanged()
    }

    suspend fun loadShown() {
        val format = awardsFormat
        run(Section.Awards(format), true) { fetchAwards(format) }
        run(Section.Discoveries(format), true) { fetchDiscoveries(format) }
    }

    suspend fun loadAwards() {
        val format = awardsFormat
        run(Section.Awards(format), true) { fetchAwards(format) }
    }

    suspend fun loadDiscoveries() {
        val format = awardsFormat
        run(Section.Discoveries(format), true) { fetchDiscoveries(format) }
    }

    suspend fun loadAlerts() {
        alertsSilenced = client.alertsSilenced()
    }

    fun dropFocus() {
        focusedAwaited = null
    }

    /** A scan asked to await a book: its tile shows at once, scrolled to, the server's after. */
    suspend fun awaitScanned(draft: BookDraft, format: ReleaseFormat) {
        val pending = AwaitedEdition.pending(format, draft)
        pendingAwaited = pendingAwaited + pending
        focusedAwaited = pending.id
        try {
            val edition = client.awaitEdition(draft, format)
            pendingAwaited = pendingAwaited.filter { it.id != pending.id }
            val kept = (feed.awaited[edition.format] ?: emptyList()).filter { it.id != edition.id }
            feed = feed.copy(awaited = feed.awaited + (edition.format to kept + edition))
            if (focusedAwaited == pending.id) focusedAwaited = edition.id
            saveSnapshot()
        } catch (error: Throwable) {
            pendingAwaited = pendingAwaited.filter { it.id != pending.id }
            if (focusedAwaited == pending.id) focusedAwaited = null
            if (!isCancellation(error)) reportError(error)
        }
    }

    /** Gives the wait up at once, and puts it back if the server refused. */
    suspend fun stopAwaiting(edition: AwaitedEdition) {
        val before = feed
        feed = feed.copy(
            awaited = feed.awaited + (edition.format to (feed.awaited[edition.format] ?: emptyList()).filter { it.id != edition.id }),
            authors = feed.authors + (edition.format to (feed.authors[edition.format] ?: emptyList()).mapNotNull { row ->
                row.copy(awaited = row.awaited.filter { it.id != edition.id }).takeUnless { it.isEmpty }
            }),
        )
        try {
            client.stopAwaiting(edition.id)
            saveSnapshot()
        } catch (error: Throwable) {
            feed = before
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    companion object {
        /** Adds a release's draft through the one "look up, then add" use case. */
        suspend fun add(draft: BookDraft) = BookAddition.add(draft, source = AnalyticsEvent.BookSource.DISCOVER)
    }
}
