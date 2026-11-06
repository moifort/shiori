package com.polyforms.shiori.features.narrators

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.authors.PersonListViewModel
import com.polyforms.shiori.features.authors.components.pages.PersonShelfAction
import com.polyforms.shiori.features.authors.components.pages.PersonShelfPage
import com.polyforms.shiori.features.library.LibraryClient
import com.polyforms.shiori.features.library.LibraryDestination
import com.polyforms.shiori.features.library.LibraryDestinationScreen
import com.polyforms.shiori.features.library.rememberBookQuickActions
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator

/** The Narrators shelf, connected. */
@Composable
fun NarratorShelfScreen(library: LibraryClient = LibraryClient.live, client: NarratorsClient = NarratorsClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { PersonListViewModel("narrators", FollowedNarrator.serializer(), scope, list = client::list) }
    val navigator = currentNavigator
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, library) }
    val quick = rememberBookQuickActions(library, ::open)

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.load(keepingDepth = true) } }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        PersonShelfPage(
            L("Narrateurs"),
            L("Narrateurs indisponibles"),
            L("Aucun narrateur préféré"),
            L("Touchez le cœur sur la page d’un narrateur pour le retrouver ici."),
            viewModel.people,
            viewModel.order,
            viewModel.isLoading,
            viewModel.errorMessage,
            viewModel.hasMore,
            viewModel.loadMoreFailed,
        ) { action ->
            when (action) {
                is PersonShelfAction.OpenPerson -> open(LibraryDestination.Narrator(NarratorDestination(action.person.key, action.person.name)))
                is PersonShelfAction.OpenBook -> open(LibraryDestination.BookPage(action.book))
                is PersonShelfAction.Order -> viewModel.show(action.order)
                is PersonShelfAction.Menu -> quick(action.book, action.action)
                is PersonShelfAction.Reached -> viewModel.prefetchIfNeeded(action.id)
                PersonShelfAction.LoadMore -> viewModel.loadMore()
                PersonShelfAction.Refresh -> viewModel.load()
            }
        }
        ScreenBar()
    }
}
