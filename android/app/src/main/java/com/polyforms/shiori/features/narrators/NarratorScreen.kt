package com.polyforms.shiori.features.narrators

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.authors.PersonCorrection
import com.polyforms.shiori.features.authors.components.organisms.PersonActionsMenu
import com.polyforms.shiori.features.authors.components.organisms.PersonMenuAction
import com.polyforms.shiori.features.authors.components.pages.PersonEditSheet
import com.polyforms.shiori.features.authors.components.pages.PortraitPickerSheet
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.library.LibraryClient
import com.polyforms.shiori.features.library.LibraryDestinationScreen
import com.polyforms.shiori.features.library.rememberBookQuickActions
import com.polyforms.shiori.features.narrators.components.pages.NarratorAction
import com.polyforms.shiori.features.narrators.components.pages.NarratorDetailPage
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.AsyncToolbarButton
import com.polyforms.shiori.shared.components.molecules.GeneratingPillHost
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

private enum class NarratorSheet { EDIT, PORTRAIT }

/** A narrator's page, connected. */
@Composable
fun NarratorScreen(key: String, name: String, client: NarratorsClient = NarratorsClient.live, library: LibraryClient = LibraryClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(key) { NarratorViewModel(key, name, client, scope) }
    val navigator = currentNavigator
    var sheet by remember { mutableStateOf<NarratorSheet?>(null) }
    val quick = rememberBookQuickActions(library) { destination -> navigator.push { LibraryDestinationScreen(destination, library) } }

    LaunchedEffect(key) {
        viewModel.load()
        viewModel.buildCatalogueIfAwaiting()
    }
    LaunchedEffect(key) { DataChanges.notices.collect { viewModel.load() } }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        NarratorDetailPage(viewModel.page, viewModel.isLoading, viewModel.errorMessage) { action ->
            when (action) {
                is NarratorAction.OpenBook -> navigator.push {
                    BookScreen(action.book.id, onChanged = { scope.launch { viewModel.load() } }, onDeleted = { scope.launch { viewModel.load() } })
                }
                is NarratorAction.OpenSeries -> navigator.push { SeriesScreen(action.seriesId) }
                is NarratorAction.Menu -> quick(action.book, action.action)
                NarratorAction.Refresh -> viewModel.load()
            }
        }
        GeneratingPillHost(viewModel.isCataloguing)
        ScreenBar(title = if (viewModel.page == null) viewModel.name else null) {
            val page = viewModel.page
            if (page != null) {
                AsyncToolbarButton(
                    if (viewModel.isFavorite) L("Retirer des préférés") else L("Préféré"),
                    if (viewModel.isFavorite) "heart.fill" else "heart",
                ) { viewModel.toggleFavorite() }
                if (page.bookCount > 0) {
                    PersonActionsMenu { action ->
                        sheet = when (action) {
                            PersonMenuAction.EDIT -> NarratorSheet.EDIT
                            PersonMenuAction.PORTRAIT -> NarratorSheet.PORTRAIT
                        }
                    }
                }
            }
        }
    }

    when (sheet) {
        NarratorSheet.EDIT -> viewModel.page?.let { page ->
            PersonEditSheet(page.facts, { sheet = null }) { viewModel.correct(it) }
        }
        NarratorSheet.PORTRAIT -> PortraitPickerSheet(
            viewModel.page?.initials ?: "",
            viewModel.portraitChoices,
            viewModel.portraitChoicesFailed,
            onLoad = viewModel::loadPortraitChoices,
            onDismiss = { sheet = null },
        ) { viewModel.correct(PersonCorrection(portraitURL = it.url)) }
        null -> Unit
    }
    val error = viewModel.errorMessage
    if (error != null && viewModel.page != null) ShioriAlert(L("Une erreur est survenue"), error, onDismiss = { viewModel.errorMessage = null })
}
