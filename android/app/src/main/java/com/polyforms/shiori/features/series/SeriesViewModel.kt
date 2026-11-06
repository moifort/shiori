package com.polyforms.shiori.features.series

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.discover.SagaDiscovery
import com.polyforms.shiori.features.discover.SagaReleases
import com.polyforms.shiori.features.discover.SagaReleasesCache
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.BookMedium
import com.polyforms.shiori.shared.BookSeries
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SeriesOpinion
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.Volume
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.datedUpTo
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.track
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.LocalDate

/** A saga's screen: its catalogue, the reader's volumes and opinion, its next release. */
class SeriesViewModel(
    val seriesId: String,
    private val proposal: SeriesProposal?,
    val friend: SeriesFriend?,
    private val client: SeriesClient,
    private val scope: CoroutineScope,
    caching: Boolean = true,
) {
    @Serializable
    data class Snapshot(val series: BookSeries?, val owned: List<Book>, val opinion: SeriesOpinion?, val releases: SagaReleases?)

    private val cache = if (caching) SnapshotCache("series-$seriesId${friend?.let { "-friend-${it.id}" } ?: ""}", 1, Snapshot.serializer()) else null

    var series by mutableStateOf<BookSeries?>(null)
        private set
    var owned by mutableStateOf<List<Book>>(emptyList())
        private set
    var opinion by mutableStateOf<SeriesOpinion?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var addingTitle by mutableStateOf<String?>(null)
        private set
    var isSaving by mutableStateOf(false)
        private set
    var isCataloguing by mutableStateOf(false)
        private set
    var isLookingUpReleases by mutableStateOf(false)
        private set
    var releases by mutableStateOf<SagaReleases?>(null)
        private set

    private var followedAhead by mutableStateOf<Boolean?>(null)
    private var followCallsInFlight by mutableIntStateOf(0)

    init {
        cache?.read()?.let {
            series = it.series
            owned = it.owned
            opinion = it.opinion
            releases = it.releases
        }
    }

    private fun keepSnapshot() {
        val cache = cache ?: return
        if (series == null && owned.isEmpty()) return
        val snapshot = Snapshot(series, owned, opinion, releases)
        scope.launch(Dispatchers.IO) { cache.write(snapshot) }
    }

    private val isShowing: Boolean get() = series != null || owned.isNotEmpty()
    val language: BookLanguage? get() = series?.language ?: owned.firstOrNull()?.language
    val isFavorite: Boolean get() = opinion?.favorite == true
    val isFollowed: Boolean get() = followedAhead ?: opinion?.follows(language) ?: true
    val takenFormat: BookFormat get() = owned.firstOrNull()?.format ?: if (series?.isAudio == true) BookFormat.AUDIOBOOK else BookFormat.BOOK
    val highestOwnedVolume: Int get() = owned.mapNotNull { it.series?.volume }.maxOrNull() ?: 0
    val isGenerating: Boolean get() = isCataloguing || isLookingUpReleases
    val name: String get() = series?.name ?: owned.firstOrNull()?.series?.name ?: ""

    val firstVolume: Volume?
        get() {
            val series = series ?: return null
            val year = LocalDate.now().year
            val datedUpTo = series.spine.datedUpTo(language, series.catalogedAt)
            return series.spine.firstOrNull { !it.isForthcoming(year, language, datedUpTo) }
        }

    suspend fun load() {
        isLoading = true
        try {
            val friend = friend
            if (friend != null) {
                loadFriendShelf(friend)
                return
            }
            val screen = client.screen(seriesId, proposal)
            series = screen.series
            opinion = screen.opinion
            owned = screen.owned
            keepSnapshot()
        } catch (error: Exception) {
            if (isCancellation(error)) return
            if (isShowing) reportError(error) else errorMessage = reportError(error)
        } finally {
            isLoading = false
        }
    }

    suspend fun buildCatalogueIfAwaiting() {
        if (series?.isAwaitingCatalogue != true || isCataloguing) return
        isCataloguing = true
        try {
            series = client.catalogue(seriesId, proposal)
            keepSnapshot()
        } catch (error: Exception) {
            reportError(error)
        } finally {
            isCataloguing = false
        }
    }

    private suspend fun loadFriendShelf(friend: SeriesFriend) {
        try {
            val (catalogue, saga) = client.friendScreen(friend.id, seriesId)
            series = catalogue
            owned = saga?.volumes.orEmpty()
            opinion = saga?.let { SeriesOpinion(seriesId, it.rating, it.favorite) }
            keepSnapshot()
        } catch (error: Exception) {
            if (isCancellation(error)) return
            if (isShowing) reportError(error) else errorMessage = reportError(error)
        }
    }

    suspend fun loadReleases() {
        if (friend != null) return
        if (releases == null) releases = SagaReleasesCache.entries[seriesId]
        try {
            var fetched = client.releases(seriesId)
            releases = fetched
            if (!fetched.watched) {
                isLookingUpReleases = true
                try {
                    fetched = client.lookUpReleases(seriesId)
                    releases = fetched
                } finally {
                    isLookingUpReleases = false
                }
            }
            SagaReleasesCache.entries[seriesId] = fetched
            keepSnapshot()
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun rate(stars: Double) = changeOpinion { if (stars == 0.0) client.removeRating(seriesId) else client.rate(seriesId, stars) }

    suspend fun setFollowed(followed: Boolean) {
        followedAhead = followed
        followCallsInFlight++
        try {
            val saved = client.setFollowed(seriesId, followed)
            if (followedAhead == followed) opinion = saved
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            followCallsInFlight--
            if (followCallsInFlight == 0) followedAhead = null
        }
    }

    suspend fun setFavorite(favorite: Boolean) = changeOpinion { client.setFavorite(seriesId, favorite) }

    private suspend fun changeOpinion(change: suspend () -> SeriesOpinion) {
        isSaving = true
        try {
            opinion = change()
            keepSnapshot()
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            isSaving = false
        }
    }

    suspend fun declareVolumeCount(count: Int): String? = try {
        opinion = client.declareVolumeCount(seriesId, count)
        load()
        null
    } catch (error: Exception) {
        reportError(error)
    }

    suspend fun delete(): Boolean {
        isSaving = true
        return try {
            client.delete(seriesId)
            cache?.forget()
            true
        } catch (error: Exception) {
            errorMessage = reportError(error)
            false
        } finally {
            isSaving = false
        }
    }

    suspend fun correct(correction: SeriesCorrection): String? = try {
        client.correct(seriesId, correction)?.let { series = it }
        load()
        null
    } catch (error: Exception) {
        reportError(error)
    }

    suspend fun mergeCandidates(): List<FollowedSeries> = client.mergeCandidates()

    suspend fun merge(target: FollowedSeries): String? = try {
        client.merge(seriesId, target.seriesId)
        null
    } catch (error: Exception) {
        reportError(error)
    }

    suspend fun correctGenre(correction: BookCorrection): String? {
        val volume = owned.firstOrNull() ?: return null
        return try {
            val updated = client.updateBook(volume.id, correction)
            owned = owned.map { book ->
                book.copy(
                    genre = if (correction.genre != null) updated.genre else book.genre,
                    subgenres = if (correction.subgenres != null) updated.subgenres else book.subgenres,
                )
            }
            null
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun subgenres(): List<String> = runCatching { client.subgenres() }.getOrDefault(emptyList())

    /** Adds a volume the reader lacks: a recording from Audible when it can, else looked up. */
    suspend fun add(volume: Volume, author: String, format: BookFormat? = null, status: ReadingStatus = ReadingStatus.TO_READ) {
        addingTitle = volume.title
        try {
            val chosen = format ?: takenFormat
            val number = volume.number
            if (chosen == BookFormat.AUDIOBOOK && volume.kind == VolumeKind.MAIN && number != null) {
                val heard = addHeard(number, status)
                if (heard != null) {
                    owned = owned + heard
                    return
                }
            }
            val media = owned.firstOrNull { it.format != BookFormat.AUDIOBOOK }?.media?.ifEmpty { null } ?: listOf(BookMedium.PRINT)
            val membership = SeriesMembership(seriesId, series?.name ?: owned.firstOrNull()?.series?.name ?: volume.title, volume.number, volume.kind)
            val draft = BookDraft(title = volume.title, authors = listOf(author), format = chosen, media = media, series = membership, language = language, status = status)
            val lookUp = if (series?.isProvisional == true) null else BookAddition.LookUp.Volume(volume.title, author, membership, chosen, media, language)
            owned = owned + client.addBook(draft, lookUp)
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            addingTitle = null
        }
    }

    private suspend fun addHeard(number: Int, status: ReadingStatus): Book? {
        var heard = try {
            client.addAudibleVolume(seriesId, number)
        } catch (error: Exception) {
            val code = (error as? ApiError)?.domainCode
            if (code != "NOT_FOUND" && code != "AUDIBLE_NOT_CONNECTED") reportError(error)
            return null
        }
        track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.SERIES))
        if (status != ReadingStatus.TO_READ) {
            try {
                heard = client.setStatus(heard.id, status)
            } catch (error: Exception) {
                errorMessage = reportError(error)
            }
        }
        return heard
    }

    fun announcedVolume(volume: Volume): DiscoveredVolume? {
        val number = volume.number ?: return null
        if (volume.kind != VolumeKind.MAIN) return null
        val release = language?.let { volume.release(it) } ?: return null
        val next = releases?.next
        if (next != null && next.number == number) return next
        return DiscoveredVolume(number, release.title, release.date, null, release.coverURL)
    }

    val announcedSaga: SagaDiscovery?
        get() {
            val series = series ?: return null
            val language = language ?: return null
            val followed = FollowedSeries(
                seriesId = seriesId,
                name = series.name,
                isAudio = series.isAudio,
                author = series.author,
                language = language,
                state = null,
                genre = owned.firstOrNull()?.genre,
                ownedCount = owned.size,
            )
            return SagaDiscovery(followed, releases ?: SagaReleases(true, null))
        }
}
