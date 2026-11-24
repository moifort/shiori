package com.polyforms.shiori.features.authors

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.news.NewsApi
import com.polyforms.shiori.features.news.UpcomingReleaseScreen
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.SnapshotCache
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import com.polyforms.shiori.features.authors.components.pages.PersonShelfAction
import com.polyforms.shiori.features.authors.components.pages.PersonShelfPage
import com.polyforms.shiori.features.library.LibraryClient
import com.polyforms.shiori.features.library.LibraryDestination
import com.polyforms.shiori.features.library.LibraryDestinationScreen
import com.polyforms.shiori.features.library.rememberBookQuickActions
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.PushedScrollAwayBar
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import com.polyforms.shiori.shared.platform.currentNavigator

/** The section's last rows on disk, so the shelf opens on them. Bump the version whenever `UpcomingRelease` changes shape. */
private val authorReleasesCache = SnapshotCache("author-releases", 1, ListSerializer(UpcomingRelease.serializer()))

/**
 * The Authors shelf, connected. "Prochaines sorties" — what the hearted authors announced — opens
 * on last session's snapshot and is brought up to date underneath.
 */
@Composable
fun AuthorShelfScreen(
    order: AuthorListOrder = AuthorListOrder.RECENT,
    client: AuthorsClient = AuthorsClient.live,
    library: LibraryClient = LibraryClient.live,
    upcoming: suspend () -> List<UpcomingRelease> = NewsApi::upcoming,
) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { PersonListViewModel("authors", FollowedAuthor.serializer(), scope, openedOrder = order, list = client::myAuthorsPage) }
    var releases by remember { mutableStateOf(FavoriteAuthorReleases.stillAhead(authorReleasesCache.read() ?: emptyList())) }
    val navigator = currentNavigator
    fun open(destination: LibraryDestination) = navigator.push { LibraryDestinationScreen(destination, library) }
    val quick = rememberBookQuickActions(library, ::open)

    // Everything announced, read off the release watches with no web lookup, kept to the hearted
    // authors. A failure leaves the section as it was: it is gone when it has nothing to show.
    suspend fun loadReleases() {
        val fresh = runCatching {
            coroutineScope {
                val all = async { upcoming() }
                val loved = async { client.myAuthorsPage(200, null, AuthorListOrder.LOVED) }
                FavoriteAuthorReleases.of(all.await(), loved.await().items.filter { it.favorite }.map { it.name })
            }
        }.getOrNull() ?: return
        if (fresh == releases) return
        releases = fresh
        scope.launch(Dispatchers.IO) { authorReleasesCache.write(fresh) }
    }

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { loadReleases() }
    LaunchedEffect(Unit) {
        DataChanges.notices.collect {
            scope.launch { viewModel.load(keepingDepth = true) }
            scope.launch { loadReleases() }
        }
    }

    val bar = rememberScrollAwayState()
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).nestedScroll(bar.connection)) {
        PersonShelfPage(
            L("Auteurs"),
            L("Auteurs indisponibles"),
            L("Aucun auteur préféré"),
            L("Touchez le cœur sur la page d’un auteur pour le retrouver ici."),
            viewModel.people,
            viewModel.order,
            viewModel.isLoading,
            viewModel.errorMessage,
            viewModel.hasMore,
            viewModel.loadMoreFailed,
            releases = releases,
            // Opens what the release opens in Actualités: the announced volume, the awaited
            // edition, the author's page.
            onOpenRelease = { release -> navigator.push { UpcomingReleaseScreen(release) } },
            allTitle = L("Tous les auteurs"),
        ) { action ->
            when (action) {
                is PersonShelfAction.OpenPerson -> open(LibraryDestination.Author(AuthorDestination(action.person)))
                is PersonShelfAction.OpenBook -> open(LibraryDestination.BookPage(action.book))
                is PersonShelfAction.Order -> viewModel.show(action.order)
                is PersonShelfAction.Menu -> quick(action.book, action.action)
                is PersonShelfAction.Reached -> viewModel.prefetchIfNeeded(action.id)
                PersonShelfAction.LoadMore -> viewModel.loadMore()
                PersonShelfAction.Refresh -> viewModel.load()
            }
        }
        PushedScrollAwayBar(bar)
    }
}

