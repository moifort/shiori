package com.polyforms.shiori.features.library

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookGenre
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.ListSection
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.ZoneId

/** One Library shelf: its books paged in, sectioned by period, year or month. */
class BookShelfViewModel(
    private val client: LibraryClient,
    private val scope: CoroutineScope,
    shelf: BookShelf,
    view: ShelvesView = ShelvesView(),
    status: ReadingStatus? = null,
    formats: List<BookFormat> = emptyList(),
    private val caching: Boolean = true,
    private val now: () -> Instant = { Instant.now() },
) {
    @Serializable
    data class Snapshot(val books: List<Book>, val lovedSeries: List<FollowedSeries>, val formats: List<BookFormat>, val genres: List<BookGenre>)

    var query by mutableStateOf(ShelfQuery(shelf, view, status))
        private set
    var books by mutableStateOf<List<Book>>(emptyList())
        private set
    var lovedSeries by mutableStateOf<List<FollowedSeries>>(emptyList())
        private set
    var isLoading by mutableStateOf(false)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var hasMore by mutableStateOf(false)
        private set
    var loadMoreFailed by mutableStateOf(false)
        private set
    var formats by mutableStateOf(formats)
        private set
    var genres by mutableStateOf<List<BookGenre>>(emptyList())
        private set
    private var isLoadingMore = false
    private var loaded = false
    private var generation = 0
    private var reloadJob: Job? = null

    val shelf: BookShelf get() = query.shelf
    private val pageSize: Int get() = if (shelf == BookShelf.ALL) 140 else 60
    private val prefetchThreshold: Int get() = if (shelf == BookShelf.ALL) 42 else 12

    val statusPills: List<ReadingStatus>
        get() = if (shelf == BookShelf.RECENT) listOf(ReadingStatus.TO_READ, ReadingStatus.READING, ReadingStatus.READ) else emptyList()
    val genrePills: List<BookGenre> get() = if (shelf == BookShelf.LOVED && genres.size > 1) genres else emptyList()
    val shownFormats: List<BookFormat>
        get() = if (shelf != BookShelf.RECENT && shelf !in formatsAbove && formats.size > 1) formats else emptyList()

    val sections: List<ListSection<Book>>
        get() = when (shelf) {
            BookShelf.RECENT, BookShelf.READ -> ListSection.byPeriod(books, { it.shelvedAt }, now())
            BookShelf.LOVED -> ListSection.byYear(books) { it.shelvedAt }
            BookShelf.ALL -> ListSection.byMonth(books) { it.shelvedAt }
            BookShelf.TO_READ, BookShelf.DROPPED -> if (books.isEmpty()) emptyList() else listOf(ListSection("all", "", books))
        }

    init {
        cache(query)?.read()?.let(::show)
    }

    private fun cache(query: ShelfQuery) = if (!caching) {
        null
    } else {
        val status = query.status?.name?.lowercase() ?: "any"
        SnapshotCache("book-shelf-${query.shelf.name.lowercase()}-${query.view.cacheKey}-$status", 1, Snapshot.serializer())
    }

    private fun show(snapshot: Snapshot) {
        books = snapshot.books
        lovedSeries = snapshot.lovedSeries
        if (formats.isEmpty()) formats = snapshot.formats
        if (genres.isEmpty()) genres = snapshot.genres
    }

    fun select(status: ReadingStatus?) {
        if (query.status == status) return
        query = query.copy(status = status)
        scheduleReload()
    }

    fun select(genre: BookGenre?) {
        if (query.view.genre == genre) return
        query = query.copy(view = query.view.copy(genre = genre))
        scheduleReload()
    }

    fun select(format: BookFormat?) {
        if (query.view.format == format) return
        query = query.copy(view = query.view.copy(format = format))
        scheduleReload()
    }

    private fun scheduleReload() {
        reloadJob?.cancel()
        generation += 1
        hasMore = false
        loaded = false
        cache(query)?.read()?.let(::show)
        reloadJob = scope.launch { load() }
    }

    suspend fun loadOnAppear() {
        if (loaded || isLoading) return
        load()
    }

    suspend fun load(keepingDepth: Boolean = false) {
        generation += 1
        val requested = generation
        val wanted = if (keepingDepth) maxOf(books.size, pageSize) else pageSize
        val asked = query
        isLoading = true
        errorMessage = null
        loadMoreFailed = false
        try {
            coroutineScope {
                val sagas = async { if (shelf == BookShelf.LOVED) client.lovedSeries(asked.view) else emptyList() }
                val fetched = mutableListOf<Book>()
                var more = true
                while (more && fetched.size < wanted) {
                    val page = client.shelf(asked, minOf(wanted - fetched.size, 200), fetched.lastOrNull()?.id)
                    if (requested != generation) return@coroutineScope
                    fetched += page.books
                    more = page.hasMore && page.books.isNotEmpty()
                }
                val kept = withinShelf(fetched)
                val loved = sagas.await()
                if (requested != generation) return@coroutineScope
                books = kept
                lovedSeries = loved
                hasMore = more && kept.size == fetched.size
                val held = fetched + loved.flatMap { it.volumes }
                if (formats.isEmpty() && asked.view.format == null) formats = BookFormat.entries.filter { f -> held.any { it.format == f } }
                if (genres.isEmpty() && asked.view.genre == null) genres = BookGenre.alphabetical.filter { g -> held.any { it.genre == g } }
                loaded = true
                cache(asked)?.let { cache ->
                    val snapshot = Snapshot(kept.take(pageSize), loved, formats, genres)
                    scope.launch(Dispatchers.IO) { cache.write(snapshot) }
                }
            }
        } catch (error: Exception) {
            if (requested == generation && !isCancellation(error)) errorMessage = reportError(error)
        } finally {
            if (requested == generation) isLoading = false
        }
    }

    suspend fun shareMessage(): String? = try {
        val all = mutableListOf<Book>()
        var more = true
        while (more) {
            val page = client.shelf(query, 200, all.lastOrNull()?.id)
            all += page.books
            more = page.hasMore && page.books.isNotEmpty()
        }
        LovedShareMessage.text(all, lovedSeries)
    } catch (error: Exception) {
        if (!isCancellation(error)) errorMessage = reportError(error)
        null
    }

    suspend fun loadMore() {
        val last = books.lastOrNull()
        if (!hasMore || isLoadingMore || last == null) return
        val requested = generation
        isLoadingMore = true
        loadMoreFailed = false
        try {
            val page = client.shelf(query, pageSize, last.id)
            if (requested != generation) return
            val kept = withinShelf(page.books, books.size)
            books = books + kept
            hasMore = page.hasMore && kept.size == page.books.size
            if (query.view.format == null) {
                val added = BookFormat.entries.filter { f -> f !in formats && kept.any { it.format == f } }
                if (added.isNotEmpty()) formats = formats + added
            }
            if (query.view.genre == null) {
                val added = kept.mapNotNull { it.genre }.toSet() - genres.toSet()
                if (added.isNotEmpty()) genres = BookGenre.alphabetical.filter { it in genres || it in added }
            }
        } catch (error: Exception) {
            if (isCancellation(error) || requested != generation) return
            loadMoreFailed = true
            errorMessage = reportError(error)
        } finally {
            isLoadingMore = false
        }
    }

    fun prefetchIfNeeded(bookId: String) {
        if (!hasMore || isLoadingMore) return
        val index = books.indexOfFirst { it.id == bookId }
        if (index >= 0 && books.size - index <= prefetchThreshold) scope.launch { loadMore() }
    }

    /** The recent shelf keeps six months, and never fewer than twenty books. */
    private fun withinShelf(fetched: List<Book>, shown: Int = 0): List<Book> {
        if (shelf != BookShelf.RECENT) return fetched
        val limit = now().atZone(ZoneId.systemDefault()).minusMonths(RECENT_MONTHS).toInstant()
        return fetched.filterIndexed { index, book -> shown + index < RECENT_FLOOR || (book.shelvedAt ?: Instant.MIN) >= limit }
    }

    companion object {
        private const val RECENT_MONTHS = 6L
        private const val RECENT_FLOOR = 20
        private val formatsAbove = setOf(BookShelf.READ, BookShelf.LOVED)
    }
}
