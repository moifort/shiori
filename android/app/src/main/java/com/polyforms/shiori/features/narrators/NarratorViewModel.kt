package com.polyforms.shiori.features.narrators

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.authors.PersonCorrection
import com.polyforms.shiori.features.authors.PortraitChoice
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SnapshotCache
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

/** A narrator's page: the recordings the reader holds of them, the heart, corrections. */
class NarratorViewModel(
    val key: String,
    val name: String,
    private val client: NarratorsClient,
    private val scope: CoroutineScope,
    caching: Boolean = true,
) {
    private val cache = if (caching) SnapshotCache("narrator-$key", 1, NarratorPage.serializer()) else null

    var page by mutableStateOf(cache?.read())
        private set
    var isLoading by mutableStateOf(true)
        private set
    var errorMessage by mutableStateOf<String?>(null)
    var isCataloguing by mutableStateOf(false)
        private set
    var portraitChoices by mutableStateOf<List<PortraitChoice>?>(null)
        private set
    var portraitChoicesFailed by mutableStateOf<String?>(null)
        private set

    val isFavorite: Boolean get() = page?.favorite ?: false

    private fun keep(fresh: NarratorPage?) {
        page = fresh
        val cache = cache ?: return
        if (fresh != null) scope.launch(Dispatchers.IO) { cache.write(fresh) }
    }

    suspend fun load() {
        isLoading = true
        try {
            val fresh = client.page(key, name)
            keep(fresh)
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
            client.catalogue(key, name)?.let { keep(it) }
        } catch (error: Exception) {
            if (!isCancellation(error)) reportError(error)
        } finally {
            isCataloguing = false
        }
    }

    suspend fun toggleFavorite() {
        val current = page ?: return
        val wanted = !current.favorite
        page = current.copy(favorite = wanted)
        try {
            val kept = client.setFavorite(key, wanted)
            page = page?.copy(favorite = kept)
        } catch (error: Exception) {
            page = page?.copy(favorite = !wanted)
            if (!isCancellation(error)) errorMessage = reportError(error)
        }
    }

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
}
