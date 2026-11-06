package com.polyforms.shiori.shared.platform

import androidx.compose.foundation.layout.Arrangement
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
