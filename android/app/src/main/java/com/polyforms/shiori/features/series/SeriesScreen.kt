package com.polyforms.shiori.features.series

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.book.components.pages.GenreEditSheet
import com.polyforms.shiori.features.book.components.pages.RatingPromptSheet
import com.polyforms.shiori.features.book.components.pages.RatingSubject
import com.polyforms.shiori.features.discover.AnnouncedVolumeScreen
import com.polyforms.shiori.features.friends.FriendBookScreen
import com.polyforms.shiori.features.series.components.organisms.SeriesActionsMenu
import com.polyforms.shiori.features.series.components.organisms.SeriesMenuAction
import com.polyforms.shiori.features.series.components.pages.MergeSeriesSheet
import com.polyforms.shiori.features.series.components.pages.SeriesAction
import com.polyforms.shiori.features.series.components.pages.SeriesEditSheet
import com.polyforms.shiori.features.series.components.pages.SeriesPage
import com.polyforms.shiori.features.series.components.pages.VolumeCountSheet
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

private enum class SeriesSheet { RATE, MERGE, VOLUME_COUNT, EDIT, GENRE }

/** A saga, the reader's or a friend's copy of it. */
@Composable
fun SeriesScreen(seriesId: String, proposal: SeriesProposal? = null, friend: SeriesFriend? = null, client: SeriesClient = SeriesClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(seriesId, friend) { SeriesViewModel(seriesId, proposal, friend, client, scope) }
    val navigator = currentNavigator
    var sheet by remember { mutableStateOf<SeriesSheet?>(null) }
    var merged by remember { mutableStateOf(false) }

    LaunchedEffect(seriesId) {
        viewModel.load()
        viewModel.buildCatalogueIfAwaiting()
    }
    LaunchedEffect(seriesId) { viewModel.loadReleases() }
    LaunchedEffect(seriesId) {
        DataChanges.notices.collect {
            if (it == null) {
                viewModel.load()
                viewModel.loadReleases()
            }
        }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        SeriesPage(
            series = viewModel.series,
            owned = viewModel.owned,
            opinion = viewModel.opinion,
            isLoading = viewModel.isLoading,
            errorMessage = viewModel.errorMessage.takeIf { viewModel.series == null },
            language = viewModel.language,
            friend = viewModel.friend,
            isFollowed = viewModel.isFollowed,
            addingTitle = viewModel.addingTitle,
            releases = viewModel.releases,
            takenFormat = viewModel.takenFormat,
            announcedVolume = viewModel::announcedVolume,
        ) { action ->
            when (action) {
                is SeriesAction.OpenBook -> navigator.push {
                    val f = viewModel.friend
                    if (f != null) {
                        FriendBookScreen(f.id, action.book.id, f.name)
                    } else {
                        BookScreen(action.book.id, onChanged = { scope.launch { viewModel.load() } }, onDeleted = { scope.launch { viewModel.load() } })
                    }
                }
                SeriesAction.Rate -> sheet = SeriesSheet.RATE
                SeriesAction.EditGenre -> sheet = SeriesSheet.GENRE
                is SeriesAction.SetFollowed -> viewModel.setFollowed(action.followed)
                is SeriesAction.OpenAuthor -> navigator.push { AuthorScreen(action.author.key, action.author.name) }
                is SeriesAction.OpenAnnounced -> viewModel.announcedSaga?.let { saga -> navigator.push { AnnouncedVolumeScreen(saga, action.volume, linksToSaga = false) } }
                is SeriesAction.Add -> viewModel.add(action.volume, action.author, action.format, action.status)
                SeriesAction.Retry -> viewModel.load()
                SeriesAction.DeclareVolumeCount -> sheet = SeriesSheet.VOLUME_COUNT
            }
        }
        GeneratingPillHost(viewModel.isGenerating)
        if (viewModel.isSaving) Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.1f)), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        ScreenBar(title = if (viewModel.series == null) viewModel.name.ifEmpty { L("Série") } else null) {
            if (viewModel.friend == null) {
                AsyncToolbarButton(if (viewModel.isFavorite) L("Retirer des favoris") else L("Ajouter aux favoris"), if (viewModel.isFavorite) "heart.fill" else "heart") {
                    viewModel.setFavorite(!viewModel.isFavorite)
                }
                val series = viewModel.series
                val first = viewModel.firstVolume
                if (viewModel.owned.isEmpty() && series != null && first != null) {
                    AsyncToolbarButton(L("Ajouter à mes séries"), "plus", enabled = viewModel.addingTitle == null) { viewModel.add(first, series.author) }
                }
                if (viewModel.owned.isNotEmpty()) {
                    SeriesActionsMenu(viewModel.series?.isProvisional == true, viewModel.owned.size) { action ->
                        when (action) {
                            SeriesMenuAction.EDIT -> sheet = SeriesSheet.EDIT
                            SeriesMenuAction.DECLARE_VOLUME_COUNT -> sheet = SeriesSheet.VOLUME_COUNT
                            SeriesMenuAction.MERGE -> sheet = SeriesSheet.MERGE
                            SeriesMenuAction.DELETE -> scope.launch { if (viewModel.delete()) navigator.pop() }
                        }
                    }
                }
            }
        }
    }

    val dismiss = { sheet = null }
    when (sheet) {
        SeriesSheet.RATE -> RatingPromptSheet(
            viewModel.opinion?.rating,
            dismiss,
            subject = RatingSubject.SERIES,
            onRemove = {
                sheet = null
                scope.launch { viewModel.rate(0.0) }
            },
        ) { stars ->
            sheet = null
            scope.launch { viewModel.rate(stars) }
        }
        SeriesSheet.MERGE -> MergeSeriesSheet(
            viewModel.seriesId,
            viewModel.name,
            viewModel.series?.isAudio ?: (viewModel.owned.firstOrNull()?.format == BookFormat.AUDIOBOOK),
            viewModel.series?.author ?: viewModel.owned.firstOrNull()?.authors?.firstOrNull(),
            viewModel.owned.size,
            viewModel::mergeCandidates,
            onDismiss = {
                sheet = null
                if (merged) navigator.pop()
            },
        ) { target ->
            viewModel.merge(target).also { if (it == null) merged = true }
        }
        SeriesSheet.VOLUME_COUNT -> VolumeCountSheet(viewModel.name, viewModel.opinion?.volumeCount ?: maxOf(viewModel.highestOwnedVolume, 1), dismiss) { viewModel.declareVolumeCount(it) }
        SeriesSheet.EDIT -> SeriesEditSheet(
            viewModel.name,
            viewModel.takenFormat,
            viewModel.series?.description,
            viewModel.series?.isAudio ?: (viewModel.takenFormat == BookFormat.AUDIOBOOK),
            viewModel.series?.let { !it.isProvisional && !it.isAwaitingCatalogue } ?: false,
            dismiss,
        ) { viewModel.correct(it) }
        SeriesSheet.GENRE -> viewModel.owned.firstOrNull()?.let { volume ->
            GenreEditSheet(volume, viewModel::subgenres, dismiss) { viewModel.correctGenre(it) }
        }
        null -> Unit
    }
    val error = viewModel.errorMessage
    if (error != null && viewModel.series != null) ShioriAlert(L("Une erreur est survenue"), error, onDismiss = { viewModel.errorMessage = null })
}
