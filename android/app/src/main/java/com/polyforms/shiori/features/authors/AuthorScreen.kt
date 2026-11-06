package com.polyforms.shiori.features.authors

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.authors.components.organisms.PersonActionsMenu
import com.polyforms.shiori.features.authors.components.organisms.PersonMenuAction
import com.polyforms.shiori.features.authors.components.pages.AuthorAction
import com.polyforms.shiori.features.authors.components.pages.AuthorDetailPage
import com.polyforms.shiori.features.authors.components.pages.AuthorWorkPage
import com.polyforms.shiori.features.authors.components.pages.PersonEditSheet
import com.polyforms.shiori.features.authors.components.pages.PortraitPickerSheet
import com.polyforms.shiori.features.book.BookScreen
import com.polyforms.shiori.features.library.LibraryClient
import com.polyforms.shiori.features.library.LibraryDestinationScreen
import com.polyforms.shiori.features.library.rememberBookQuickActions
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

private enum class AuthorSheet { EDIT, PORTRAIT }

/** An author's page, connected: loads it, opens what it links to, corrects it. */
@Composable
fun AuthorScreen(
    key: String,
    name: String,
    isOffered: Boolean = false,
    client: AuthorsClient = AuthorsClient.live,
    library: LibraryClient = LibraryClient.live,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember(key) { AuthorViewModel(key, name, isOffered, client, scope) }
    val navigator = currentNavigator
    var sheet by remember { mutableStateOf<AuthorSheet?>(null) }
    val quick = rememberBookQuickActions(library) { destination -> navigator.push { LibraryDestinationScreen(destination, library) } }

    LaunchedEffect(key) {
        viewModel.load()
        viewModel.buildCatalogueIfAwaiting()
    }
    LaunchedEffect(key) { DataChanges.notices.collect { viewModel.load() } }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        AuthorDetailPage(viewModel.page, viewModel.isLoading, viewModel.errorMessage) { action ->
            when (action) {
                is AuthorAction.OpenBook -> navigator.push {
                    BookScreen(action.book.id, onChanged = { scope.launch { viewModel.load() } }, onDeleted = { scope.launch { viewModel.load() } })
                }
                is AuthorAction.OpenSeries -> navigator.push { SeriesScreen(action.seriesId, action.proposal) }
                is AuthorAction.OpenWork -> navigator.push {
                    val author = viewModel.page?.author?.name ?: viewModel.name
                    AuthorWorkPage(action.work, author, viewModel.adding == action.work.id) {
                        viewModel.add(action.work, author, AuthorShelfFormat.PRINT)
                        navigator.pop()
                    }
                }
                is AuthorAction.Menu -> quick(action.book, action.action)
                AuthorAction.Refresh -> viewModel.load()
            }
        }
        GeneratingPillHost(viewModel.isGenerating)
        ScreenBar(title = if (viewModel.page == null) viewModel.name else null) {
            val page = viewModel.page
            if (page != null) {
                AsyncToolbarButton(
                    if (viewModel.isFavorite) L("Retirer des préférés") else L("Préféré"),
                    if (viewModel.isFavorite) "heart.fill" else "heart",
                ) { viewModel.toggleFavorite() }
                if (page.author.bookCount > 0) {
                    PersonActionsMenu { action ->
                        sheet = when (action) {
                            PersonMenuAction.EDIT -> AuthorSheet.EDIT
                            PersonMenuAction.PORTRAIT -> AuthorSheet.PORTRAIT
                        }
                    }
                }
            }
        }
    }

    when (sheet) {
        AuthorSheet.EDIT -> viewModel.page?.let { page ->
            PersonEditSheet(page.facts, { sheet = null }) { viewModel.correct(it) }
        }
        AuthorSheet.PORTRAIT -> PortraitPickerSheet(
            viewModel.page?.author?.initials ?: "",
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
