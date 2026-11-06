package com.polyforms.shiori.features.discover

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.polyforms.shiori.features.authors.AuthorScreen
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.discover.components.pages.DiscoverAction
import com.polyforms.shiori.features.discover.components.pages.DiscoverPage
import com.polyforms.shiori.features.friends.FriendBookScreen
import com.polyforms.shiori.features.home.HomeClient
import com.polyforms.shiori.features.series.SeriesProposal
import com.polyforms.shiori.features.series.SeriesScreen
import com.polyforms.shiori.features.settings.NotificationSettingsScreen
import com.polyforms.shiori.shared.DataChanges
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.molecules.LibraryShelf
import com.polyforms.shiori.shared.components.molecules.LibraryShelfPicker
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.launch

/**
 * Découvrir, connected: owns the view model, its loads and the change notices, and every page it
 * opens. The server looks the sagas up on the web once a week; the screen opens on what it last
 * showed, brought up to date silently underneath.
 */
@Composable
fun DiscoverScreen(client: DiscoverClient = DiscoverClient.live, onClose: () -> Unit) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { DiscoverViewModel(client, scope) }
    val navigator = currentNavigator
    var shelf by rememberSaveable { mutableStateOf(LibraryShelf.BOOKS) }
    val choices = remember { DiscoveryChoices() }

    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { DataChanges.notices.collect { viewModel.libraryChanged() } }
    LaunchedEffect(Unit) { AwaitedApi.didChange.collect { viewModel.awaitedChanged() } }
    DisposableEffect(Unit) { onDispose { viewModel.dropFocus() } }

    // What a suggestion's page decides, through the same writes as the Home's discoveries.
    suspend fun choose(suggestion: Suggestion, choice: DiscoveryChoice): Boolean {
        val home = HomeClient.live
        return try {
            when (choice) {
                DiscoveryChoice.Add -> home.addBook(suggestion.shelfDraft(ReadingStatus.TO_READ))
                is DiscoveryChoice.Await -> home.awaitEdition(suggestion.draft, choice.format)
                DiscoveryChoice.AlreadyRead -> home.addBook(suggestion.shelfDraft(ReadingStatus.READ))
                DiscoveryChoice.Wish -> home.wish(suggestion.shelfDraft(ReadingStatus.TO_READ))
                DiscoveryChoice.UndoAlreadyRead -> Unit
                DiscoveryChoice.NotInterested -> home.dismissSuggestion(suggestion.id, DismissalReason.NOT_INTERESTED)
                DiscoveryChoice.Reconsider -> home.reconsiderSuggestion(suggestion.id)
            }
            scope.launch { viewModel.loadDiscoveries() }
            true
        } catch (error: Throwable) {
            if (!isCancellation(error)) reportError(error)
            false
        }
    }

    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        DiscoverPage(
            shelf,
            viewModel.feed,
            viewModel.awaitedSoon,
            viewModel.focusedAwaited,
            viewModel.shownAwards,
            viewModel.discoveriesLine,
            viewModel.isLookingUp,
            viewModel.isLoading,
            viewModel.errorMessage,
        ) { action ->
            when (action) {
                is DiscoverAction.OpenSeries -> navigator.push { SeriesScreen(action.row.series.seriesId) }
                is DiscoverAction.OpenVolume -> navigator.push { AnnouncedVolumeScreen(action.volume.saga, action.volume.volume) }
                is DiscoverAction.OpenAuthor -> navigator.push { AuthorScreen(action.key, action.name, isOffered = action.isOffered) }
                is DiscoverAction.OpenFriendBook -> navigator.push {
                    val lover = action.loved.lovers.first
                    FriendBookScreen(lover?.userId ?: "", action.loved.book.id, lover?.displayName ?: "")
                }
                // The reader holds no volume of it: the saga is named to the server.
                is DiscoverAction.OpenFriendSaga -> navigator.push {
                    val saga = action.loved.saga
                    SeriesScreen(saga.seriesId, proposal = saga.author?.let { SeriesProposal(saga.name, it) })
                }
                is DiscoverAction.OpenAwaited -> navigator.push {
                    AwaitedEditionScreen(action.edition) { scope.launch { viewModel.stopAwaiting(action.edition) } }
                }
                is DiscoverAction.OpenWinner -> navigator.push {
                    AwardWinnerScreen(action.winner, viewModel.shownAwards.flatMap { it.winners }.latestFirst)
                }
                is DiscoverAction.OpenSuggestion -> navigator.push { SuggestionScreen(action.suggestion, choices, ::choose) }
                DiscoverAction.Refresh -> viewModel.refresh()
                DiscoverAction.Retry -> viewModel.loadAll()
            }
        }
        ScreenBar(onBack = onClose) {
            // The release alerts, where the releases are; the bell is read again on return.
            ToolbarIconButton(L("Notifications"), if (viewModel.alertsSilenced) "bell.slash" else "bell") {
                navigator.push { NotificationSettingsScreen() }
            }
        }
        Box(Modifier.align(Alignment.BottomCenter).navigationBarsPadding()) {
            LibraryShelfPicker(shelf, { shelf = it }, listOf(LibraryShelf.BOOKS, LibraryShelf.SERIES, LibraryShelf.AUTHORS))
        }
    }
    LaunchedEffect(navigator.depth) { if (navigator.depth == 0) viewModel.loadAlerts() }
}
