package com.polyforms.shiori.features.authors

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookAddition
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SeriesMembership
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.VolumeKind
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** An author's page: what the reader holds of them, their catalogue, the heart, corrections. */
class AuthorViewModel(
    val key: String,
    val name: String,
    private val isOffered: Boolean,
    private val client: AuthorsClient,
    private val scope: CoroutineScope,
    caching: Boolean = true,
) {
    private val cache = if (caching) SnapshotCache("author-$key", 1, AuthorPage.serializer()) else null

    var page by mutableStateOf<AuthorPage?>(null)
        private set
    var isLoading by mutableStateOf(true)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var adding by mutableStateOf<String?>(null)
        private set
    var isCataloguing by mutableStateOf(false)
        private set
    val isGenerating: Boolean get() = isCataloguing
    var portraitChoices by mutableStateOf<List<PortraitChoice>?>(null)
        private set
    var portraitChoicesFailed by mutableStateOf<String?>(null)
        private set
    var isFavorite by mutableStateOf(false)
        private set

    init {
        cache?.read()?.let {
            page = it
            isFavorite = it.author.favorite
        }
    }

    private fun keep(fresh: AuthorPage?) {
        page = fresh
        val cache = cache ?: return
        if (fresh != null) scope.launch(Dispatchers.IO) { cache.write(fresh) }
    }

    private val offered: String? get() = if (isOffered) name else null

    suspend fun load() {
        isLoading = true
        try {
            val fresh = client.page(key, offered)
            keep(fresh)
            isFavorite = fresh?.author?.favorite ?: isFavorite
            if (fresh == null) errorMessage = null
        } catch (error: Exception) {
            if (isCancellation(error)) return
            if (page == null) errorMessage = reportError(error) else reportError(error)
        } finally {
            isLoading = false
        }
    }

    suspend fun buildCatalogueIfAwaiting() {
        if (page?.isAwaitingCatalogue != true || isCataloguing) return
        isCataloguing = true
        try {
            client.catalogue(key, offered)?.let { keep(it) }
        } catch (error: Exception) {
            if (!isCancellation(error)) reportError(error)
        } finally {
            isCataloguing = false
        }
    }

    suspend fun toggleFavorite() {
        val wanted = !isFavorite
        isFavorite = wanted
        try {
            isFavorite = client.setFavorite(key, wanted)
        } catch (error: Exception) {
            isFavorite = !wanted
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

    /** Nil when the correction went through, else what to tell the reader. */
    suspend fun correct(correction: PersonCorrection): String? = try {
        client.correct(key, correction)?.let { keep(it) }
        null
    } catch (error: ApiError) {
        if (error.domainCode == "PORTRAIT_NOT_AN_IMAGE") {
            L("Cette adresse mène à une page, pas à une image. Ouvrez la photo seule, puis copiez son adresse.")
        } else {
            reportError(error)
        }
    } catch (error: Exception) {
        reportError(error)
    }

    suspend fun loadPortraitChoices() {
        portraitChoices = null
        portraitChoicesFailed = null
        try {
            portraitChoices = client.portraitChoices(key)
        } catch (error: Exception) {
            if (!isCancellation(error)) portraitChoicesFailed = reportError(error)
        }
    }

    suspend fun start(saga: AuthorSeries, author: String, format: AuthorShelfFormat) {
        adding = saga.id
        try {
            add(saga.firstVolumeTitle ?: saga.name, author, SeriesMembership(saga.id, saga.name, 1, VolumeKind.MAIN), format)
        } finally {
            adding = null
        }
    }

    suspend fun add(work: AuthorWork, author: String, format: AuthorShelfFormat) {
        adding = work.id
        try {
            add(work.title, author, null, format)
        } finally {
            adding = null
        }
    }

    private suspend fun add(title: String, author: String, series: SeriesMembership?, format: AuthorShelfFormat) {
        val draft = BookDraft(title = title, authors = listOf(author), format = format.bookFormat, series = series, status = ReadingStatus.TO_READ)
        try {
            client.addBook(draft, BookAddition.LookUp.Title("$title — $author"))
            load()
        } catch (error: Exception) {
            errorMessage = reportError(error)
        }
    }
}
