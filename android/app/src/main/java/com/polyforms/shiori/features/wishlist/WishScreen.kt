package com.polyforms.shiori.features.wishlist

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.DiscoverClient
import com.polyforms.shiori.features.discover.ReleaseCoverClient
import com.polyforms.shiori.features.discover.ReleaseCoverPicker
import com.polyforms.shiori.features.wishlist.components.pages.WishPage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator

/**
 * A book wished for, connected: opened from the pile's wishlist rail and the wishlist. Describes it
 * as it opens; once added or taken off the list, the page closes on the list that no longer holds it.
 */
@Composable
fun WishScreen(
    wish: Wish,
    client: WishlistClient = WishlistClient.live,
    discover: DiscoverClient = DiscoverClient.live,
    coverClient: ReleaseCoverClient = ReleaseCoverClient.live,
) {
    val viewModel = remember(wish.id) { WishViewModel(wish, client, discover) }
    val navigator = currentNavigator
    var choosesCover by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { viewModel.describe() }
    WishPage(
        wish = viewModel.wish,
        shown = viewModel.shown,
        storeURL = viewModel.storeURL,
        isDescribing = viewModel.isDescribing,
        onAdd = { status -> if (viewModel.add(status)) navigator.pop() },
        onRemove = { if (viewModel.remove()) navigator.pop() },
        onChooseCover = { choosesCover = true },
    )
    if (choosesCover) {
        ReleaseCoverPicker(viewModel.shown, viewModel.releaseKey, onDismiss = { choosesCover = false }, client = coverClient, onChosen = viewModel::drawCover)
    }
    viewModel.actionError?.let { ShioriAlert(L("Action impossible"), it, onDismiss = { viewModel.actionError = null }) }
}
