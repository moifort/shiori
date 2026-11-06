package com.polyforms.shiori.features.book

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.EditionOffer
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookRecommendation
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable

/** The book page's state: the book, its saga row, its covers, what it offers to await. */
class BookViewModel(
    private val bookId: String,
    private val client: BookClient,
    private val scope: CoroutineScope,
    caching: Boolean = true,
) {
    @Serializable
    data class Snapshot(val book: Book, val sagaVolumes: List<SeriesStripItem>)

    private val cache = if (caching) SnapshotCache("book-$bookId", 1, Snapshot.serializer()) else null

    var book by mutableStateOf<Book?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var errorMessage by mutableStateOf<String?>(null)
        private set
    var isSaving by mutableStateOf(false)
        private set
    var coverChoices by mutableStateOf<List<CoverChoice>?>(null)
        private set
    var coverChoicesFailed by mutableStateOf<String?>(null)
        private set
    var isDescribing by mutableStateOf(false)
        private set
    var offer by mutableStateOf(EditionOffer())
        private set
    var sagaVolumes by mutableStateOf<List<SeriesStripItem>>(emptyList())
        private set
    var awaitFailed by mutableStateOf<String?>(null)

    private val awaiting = mutableMapOf<ReleaseFormat, Deferred<AwaitedEdition?>>()

    init {
        cache?.read()?.let {
            book = it.book
            sagaVolumes = it.sagaVolumes
        }
    }

    private fun keepSnapshot() {
        val cache = cache ?: return
        val book = book ?: return
        val snapshot = Snapshot(book, sagaVolumes)
        scope.launch(Dispatchers.IO) { cache.write(snapshot) }
    }

    private fun show(book: Book?) {
        this.book = book
        keepSnapshot()
    }

    suspend fun load() {
        isLoading = true
        errorMessage = null
        try {
            val fetched = client.book(bookId)
            show(fetched)
            if (fetched == null) cache?.forget()
        } catch (error: Exception) {
            if (book == null) errorMessage = reportError(error) else reportError(error)
        }
        isLoading = false
    }

    suspend fun refresh() {
        try {
            show(client.book(bookId))
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun loadSagaVolumes() {
        val series = book?.series
        if (series == null) {
            sagaVolumes = emptyList()
            return
        }
        val volumes = runCatching { client.sagaVolumes(series.id, book?.language) }.getOrNull() ?: return
        sagaVolumes = volumes
        keepSnapshot()
    }

    /** A book added from a shelf photo is described when its page first opens. */
    suspend fun describeIfAwaiting(): Boolean {
        if (book?.awaitingDescription != true) return false
        isDescribing = true
        try {
            show(client.describe(bookId))
            return true
        } catch (error: Exception) {
            reportError(error)
            return false
        } finally {
            isDescribing = false
        }
    }

    suspend fun setStatus(status: ReadingStatus) = mutate { client.setStatus(bookId, status) }

    suspend fun recordPage(page: Int?, then: ReadingStatus? = null): Boolean {
        errorMessage = null
        if (page != null) mutate { client.recordPage(bookId, page) }
        if (errorMessage == null && then != null) setStatus(then)
        return errorMessage == null
    }

    suspend fun rate(stars: Double) = mutate { client.rate(bookId, stars) }

    suspend fun save(correction: BookCorrection, rating: Double?): Boolean {
        val current = book ?: return false
        isSaving = true
        try {
            val change = when {
                rating == current.rating -> null
                rating == null -> RatingChange.Unrate
                else -> RatingChange.Rate(rating)
            }
            client.save(bookId, correction, change)?.let(::show)
            return true
        } catch (error: Exception) {
            errorMessage = reportError(error)
            return false
        } finally {
            isSaving = false
        }
    }

    suspend fun loadCoverChoices() {
        coverChoices = null
        coverChoicesFailed = null
        try {
            coverChoices = client.coverChoices(bookId)
        } catch (error: Exception) {
            coverChoicesFailed = reportError(error)
        }
    }

    suspend fun chooseCover(choice: CoverChoice): Boolean {
        isSaving = true
        try {
            show(client.chooseCover(bookId, if (choice.source == CoverChoice.Source.PHOTO) null else choice.url))
            return true
        } catch (error: ApiError) {
            errorMessage = if (error.domainCode == "COVER_NOT_AN_IMAGE") {
                L("Cette adresse mène à une page, pas à une image. Ouvrez l'image de la couverture seule, puis copiez son adresse.")
            } else {
                reportError(error)
            }
            return false
        } catch (error: Exception) {
            errorMessage = reportError(error)
            return false
        } finally {
            isSaving = false
        }
    }

    suspend fun setFavorite(favorite: Boolean) = mutate { client.setFavorite(bookId, favorite) }

    suspend fun setRecommendation(recommendation: BookRecommendation?): Boolean = guarded { client.setRecommendation(bookId, recommendation) }

    suspend fun setNote(note: String?): Boolean = guarded { client.setNote(bookId, note) }

    suspend fun setHidden(hidden: Boolean) = mutate { client.setHidden(bookId, hidden) }

    suspend fun delete(): Boolean {
        isSaving = true
        try {
            client.delete(bookId)
            cache?.forget()
            return true
        } catch (error: Exception) {
            errorMessage = reportError(error)
            return false
        } finally {
            isSaving = false
        }
    }

    private suspend fun guarded(operation: suspend () -> Book): Boolean {
        isSaving = true
        try {
            show(operation())
            return true
        } catch (error: Exception) {
            errorMessage = reportError(error)
            return false
        } finally {
            isSaving = false
        }
    }

    /** A write that answers the book: a book turned back into one awaiting its description reads again. */
    private suspend fun mutate(operation: suspend () -> Book) {
        isSaving = true
        try {
            val answer = operation()
            show(
                if (answer.awaitingDescription && book?.awaitingDescription == false) {
                    runCatching { client.book(bookId) }.getOrNull() ?: answer
                } else {
                    answer
                },
            )
        } catch (error: Exception) {
            errorMessage = reportError(error)
        } finally {
            isSaving = false
        }
    }

    fun dismissError() {
        errorMessage = null
    }

    suspend fun loadOffer() {
        try {
            offer = client.offer(bookId) ?: EditionOffer()
        } catch (error: Exception) {
            reportError(error)
        }
    }

    /** Shows the edition as awaited at once, while the server looks it up on the web. */
    fun awaitEdition(format: ReleaseFormat) {
        val book = book ?: return
        val pending = AwaitedEdition.pending(format, book)
        offer = offer.copy(awaited = offer.awaited + pending)
        awaiting[format] = scope.async {
            try {
                val edition = client.awaitEdition(bookId, format)
                offer = offer.copy(awaited = offer.awaited.map { if (it.id == pending.id) edition else it })
                edition
            } catch (error: Exception) {
                offer = offer.copy(awaited = offer.awaited.filterNot { it.id == pending.id })
                awaitFailed = reportError(error)
                null
            } finally {
                awaiting.remove(format)
            }
        }
    }

    suspend fun stopAwaiting(edition: AwaitedEdition) {
        var target = edition
        val pending = awaiting[edition.format]
        if (pending != null) {
            offer = offer.copy(awaited = offer.awaited.filterNot { it.id == edition.id })
            target = pending.await() ?: return
        }
        try {
            client.stopAwaiting(target.id)
            offer = offer.copy(awaited = offer.awaited.filterNot { it.id == target.id })
        } catch (error: Exception) {
            awaitFailed = reportError(error)
        }
    }
}
