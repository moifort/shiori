package com.polyforms.shiori.features.wishlist

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.AwaitedApi
import com.polyforms.shiori.features.discover.AwaitedEditionScreen
import com.polyforms.shiori.features.wishlist.components.pages.WishlistAction
import com.polyforms.shiori.features.wishlist.components.pages.WishlistPage
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ScrollAwayState
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.currentNavigator
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import kotlinx.coroutines.launch

/**
 * The wishlist, connected: owns the view model and opens a book wished for or an edition's page;
 * a long press on a cover takes it off the list.
 */
@Composable
fun WishlistScreen(client: WishlistClient = WishlistClient.live) {
    val scope = rememberCoroutineScope()
    val viewModel = remember { WishlistViewModel(client, scope) }
    val navigator = currentNavigator
    val bar = rememberScrollAwayState()
    LaunchedEffect(Unit) { viewModel.loadOnAppear() }
    LaunchedEffect(Unit) { WishlistApi.didChange.collect { viewModel.load() } }
    LaunchedEffect(Unit) { AwaitedApi.didChange.collect { viewModel.load() } }
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).nestedScroll(bar.connection)) {
        WishlistPage(viewModel.shown, viewModel.formats, viewModel.format, viewModel.isLoading, viewModel.errorMessage) { action ->
            when (action) {
                is WishlistAction.OpenEdition -> navigator.push { AwaitedEditionScreen(action.edition) }
                // A book wished for opens its own page, as from the pile.
                is WishlistAction.OpenWish -> navigator.push { WishScreen(action.wish) }
                is WishlistAction.DropWish -> scope.launch { viewModel.remove(action.wish) }
                is WishlistAction.DropEdition -> scope.launch { viewModel.stopAwaiting(action.edition) }
                is WishlistAction.SelectFormat -> viewModel.format = action.format
                WishlistAction.Refresh -> viewModel.load()
            }
        }
        PushedScrollAwayBar(L("Liste d'envies"), bar) { navigator.pop() }
    }
    viewModel.actionError?.let { ShioriAlert(L("Action impossible"), it, onDismiss = { viewModel.actionError = null }) }
}

/**
 * The bar that scrolls away, on a page pushed rather than a tab's root: Back, then the page's name
 * on the left, both sent away while the reader scrolls down and called back by scrolling up.
 */
@Composable
private fun BoxScope.PushedScrollAwayBar(title: String, state: ScrollAwayState, onBack: () -> Unit) {
    val alpha by animateFloatAsState(if (state.isCalled) 1f else 0f, tween(250), label = "scrollAway")
    Row(
        Modifier.align(Alignment.TopCenter).fillMaxWidth().statusBarsPadding().height(56.dp).padding(horizontal = 16.dp)
            .graphicsLayer { this.alpha = alpha },
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (state.isCalled) ToolbarIconButton(L("Retour"), "chevron.left", onClick = onBack)
        Text(title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Shiori.colors.label, maxLines = 1)
    }
}
