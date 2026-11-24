package com.polyforms.shiori.features.narrators

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.news.NewsApi
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.SnapshotCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import com.polyforms.shiori.features.authors.AuthorListOrder
import com.polyforms.shiori.features.authors.FavoriteAuthorReleases
import com.polyforms.shiori.features.authors.releaseDestination
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

/** The section's last rows on disk, so the shelf opens on them. Bump the version whenever `UpcomingRelease` changes shape. */
private val narratorReleasesCache = SnapshotCache("narrator-releases", 1, ListSerializer(UpcomingRelease.serializer()))

/**
 * The Narrators shelf, connected. "Prochaines sorties" — what the hearted narrators recorded and is
 * announced — opens on last session's snapshot and is brought up to date underneath.
 */
@Composable
fun NarratorShelfScreen(
    order: AuthorListOrder = AuthorListOrder.RECENT,
    library: LibraryClient = LibraryClient.live,
    client: NarratorsClient = NarratorsClient.live,
    upcoming: suspend () -> List<UpcomingRelease> = NewsApi::upcoming,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { PersonListViewModel("narrators", FollowedNarrator.serializer(), scope, openedOrder = order, list = client::list) }
    var releases by remember { mutableStateOf(FavoriteAuthorReleases.stillAhead(narratorReleasesCache.read() ?: emptyList())) }
    val navigator = currentNavigator
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, library) }
    val quick = rememberBookQuickActions(library, ::open)

    // Everything announced, kept to the hearted narrators' recordings. A failure leaves the
    // section as it was: it is gone when it has nothing to show.
    suspend fun loadReleases() {
        val fresh = runCatching { FavoriteNarratorReleases.of(upcoming()) }.getOrNull() ?: return
        if (fresh == releases) return
        releases = fresh
        scope.launch(Dispatchers.IO) { narratorReleasesCache.write(fresh) }
    }

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { loadReleases() }
    LaunchedEffect(Unit) {
        DataChanges.notices.collect {
            scope.launch { viewModel.load(keepingDepth = true) }
            scope.launch { loadReleases() }
        }
    }

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
            releases = releases,
            onOpenRelease = { release -> releaseDestination(release)?.let(::open) },
            allTitle = L("Tous les narrateurs"),
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
