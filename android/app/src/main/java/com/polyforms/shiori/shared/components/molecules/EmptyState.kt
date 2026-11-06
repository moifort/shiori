package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.Symbol

/** One button of an empty state. */
data class EmptyStateAction(val title: String, val symbol: String? = null, val run: suspend () -> Unit)

/** `ContentUnavailableView`: an icon, a title, a line and up to two actions, centred. */
@Composable
fun EmptyState(
    symbol: String,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    primary: EmptyStateAction? = null,
    secondary: EmptyStateAction? = null,
) = EmptyState(symbol, title, AnnotatedString(message), modifier, primary, secondary)

@Composable
fun EmptyState(
    symbol: String,
    title: String,
    message: AnnotatedString,
    modifier: Modifier = Modifier,
    primary: EmptyStateAction? = null,
    secondary: EmptyStateAction? = null,
) {
    val colors = Shiori.colors
    Column(
        modifier.fillMaxWidth().padding(horizontal = 32.dp, vertical = 40.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Symbol(symbol), null, Modifier.size(48.dp), tint = colors.secondaryLabel)
        Text(title, style = Shiori.type.title2, color = colors.label, textAlign = TextAlign.Center)
        Text(message, style = Shiori.type.callout, color = colors.secondaryLabel, textAlign = TextAlign.Center)
        if (primary != null || secondary != null) {
            Column(
                Modifier.padding(top = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                primary?.let { ShioriButton(it.title, symbol = it.symbol, kind = ButtonKind.PROMINENT, action = it.run) }
                secondary?.let { ShioriButton(it.title, symbol = it.symbol, kind = ButtonKind.BORDERED, action = it.run) }
            }
        }
    }
}

/** A screen that could not load: the error, and a way to try again. */
@Composable
fun FailureState(title: String, message: String, modifier: Modifier = Modifier, retry: suspend () -> Unit) =
    EmptyState(
        "wifi.exclamationmark",
        title,
        message,
        modifier,
        primary = EmptyStateAction(L("Réessayer"), "arrow.clockwise", retry),
    )
