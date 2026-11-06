package com.polyforms.shiori.features.wishlist

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
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.wishlist.components.pages.WishlistAction
import com.polyforms.shiori.features.wishlist.components.pages.WishlistPage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import com.polyforms.shiori.shared.platform.ScreenBar
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import kotlinx.coroutines.launch

/** The wishlist, connected. */
@Composable
fun WishlistScreen(client: WishlistClient = WishlistClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { WishlistViewModel(client, scope) }
    val navigator = currentNavigator
    var chosen by remember { mutableStateOf<Wish?>(null) }
    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { WishlistApi.didChange.collect { viewModel.load() } }
    LaunchedEffect(Unit) { AwaitedApi.didChange.collect { viewModel.load() } }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground)) {
        WishlistPage(viewModel.shown, viewModel.formats, viewModel.format, viewModel.isLoading, viewModel.errorMessage) { action ->
            when (action) {
                is WishlistAction.OpenEdition -> navigator.push { AwaitedEditionScreen(action.edition) { scope.launch { viewModel.load() } } }
                is WishlistAction.ChooseWish -> chosen = action.wish
                is WishlistAction.SelectFormat -> viewModel.format = action.format
                WishlistAction.Refresh -> viewModel.load()
            }
        }
        ScreenBar()
    }
    chosen?.let { wish ->
        ConfirmationSheet(
            wish.title,
            listOf(
                ConfirmationChoice(L("À lire")) { scope.launch { viewModel.add(wish, ReadingStatus.TO_READ) } },
                ConfirmationChoice(L("Déjà lu")) { scope.launch { viewModel.add(wish, ReadingStatus.READ) } },
                ConfirmationChoice(L("Retirer"), destructive = true) { scope.launch { viewModel.remove(wish) } },
            ),
        ) { chosen = null }
    }
    viewModel.actionError?.let { ShioriAlert(L("Action impossible"), it, onDismiss = { viewModel.actionError = null }) }
}
