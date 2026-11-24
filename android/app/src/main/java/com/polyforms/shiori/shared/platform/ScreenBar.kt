package com.polyforms.shiori.shared.platform

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.nestedscroll.NestedScrollConnection
import androidx.compose.ui.input.nestedscroll.NestedScrollSource
import androidx.compose.ui.text.font.FontWeight
import com.polyforms.shiori.features.onboarding.LocalAccount
import com.polyforms.shiori.features.settings.SettingsHomeScreen
import com.polyforms.shiori.shared.components.molecules.AccountAvatarButton
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.styles.Shiori

/**
 * A pushed screen's bar, floating over its content as iOS 26 draws it: the back button, an
 * inline title, the trailing buttons, each in its own glass.
 */
@Composable
fun BoxScope.ScreenBar(
    title: String? = null,
    onBack: (() -> Unit)? = LocalNavigator.current?.let { nav -> { nav.pop() } },
    trailing: @Composable RowScope.() -> Unit = {},
) {
    Box(Modifier.align(Alignment.TopCenter).fillMaxWidth().statusBarsPadding().height(56.dp).padding(horizontal = 16.dp)) {
        if (onBack != null) {
            Box(Modifier.align(Alignment.CenterStart)) { ToolbarIconButton(L("Retour"), "chevron.left", onClick = onBack) }
        }
        if (title != null) {
            Text(
                title,
                style = Shiori.type.headline,
                color = Shiori.colors.label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 112.dp),
            )
        }
        Row(Modifier.align(Alignment.CenterEnd), horizontalArrangement = Arrangement.spacedBy(8.dp), content = trailing)
    }
}

/** A screen still loading: a spinner in the middle. */
@Composable
fun LoadingScreen() {
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

/** A screen's large title, under the floating bar, scrolling away with the content. */
@Composable
fun LargeTitle(title: String, modifier: Modifier = Modifier) {
    Text(
        title,
        style = Shiori.type.largeTitle,
        color = Shiori.colors.label,
        modifier = modifier.statusBarsPadding().padding(top = 56.dp).padding(horizontal = 20.dp, vertical = 4.dp),
    )
}

/**
 * Whether a bar that scrolls away is called: sent away while the reader scrolls down, called
 * back by scrolling up, as Safari brings its bar back, and always shown at the very top. Hand
 * [connection] to the page's scroll container (`Modifier.nestedScroll`), or to any of its
 * ancestors, which hear every scroll beneath them.
 */
@Stable
class ScrollAwayState {
    var isCalled by mutableStateOf(true)
        private set

    fun call(called: Boolean) {
        isCalled = called
    }

    val connection = object : NestedScrollConnection {
        override fun onPostScroll(consumed: Offset, available: Offset, source: NestedScrollSource): Offset {
            when {
                // Pulled down past the top: the page is at its start.
                available.y > 0f -> call(true)
                consumed.y < -4f -> call(false)
                consumed.y > 4f -> call(true)
            }
            return Offset.Zero
        }
    }
}

@Composable
fun rememberScrollAwayState() = remember { ScrollAwayState() }

/**
 * The bar the home draws, on a page that scrolls: the page's name on the left, the page's buttons
 * on the right, each on its own glass, all sent away together while the reader scrolls down and
 * called back by scrolling up. The bar has no ground of its own: the page runs under it. The
 * reader's avatar comes last on the right, as on every tab's root.
 */
@Composable
fun BoxScope.ScrollAwayBar(
    title: String,
    state: ScrollAwayState,
    showsAccount: Boolean = true,
    trailing: @Composable RowScope.() -> Unit = {},
) {
    val alpha by animateFloatAsState(if (state.isCalled) 1f else 0f, tween(250), label = "scrollAway")
    Row(
        Modifier
            .align(Alignment.TopCenter)
            .fillMaxWidth()
            .statusBarsPadding()
            .height(56.dp)
            .padding(horizontal = 16.dp)
            .graphicsLayer { this.alpha = alpha },
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Shiori.colors.label, maxLines = 1, modifier = Modifier.weight(1f))
        if (state.isCalled) {
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                trailing()
                if (showsAccount) AccountSettingsButton()
            }
        }
    }
}

/**
 * The reader's avatar, opening the settings: the last button on the right of every tab's root bar,
 * so the account is one tap away wherever the reader is. Pushed pages keep their own bar.
 */
@Composable
fun AccountSettingsButton() {
    val account = LocalAccount.current
    var showsSettings by remember { mutableStateOf(false) }
    AccountAvatarButton(account.avatar, account.firstName) { showsSettings = true }
    if (showsSettings) {
        ShioriSheet({ showsSettings = false }) {
            Box(Modifier.fillMaxSize()) { NavigationStack { SettingsHomeScreen() } }
        }
    }
}
