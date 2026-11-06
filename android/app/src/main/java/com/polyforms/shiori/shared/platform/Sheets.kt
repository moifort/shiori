package com.polyforms.shiori.shared.platform

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import kotlinx.coroutines.launch

/**
 * A page sheet, as SwiftUI's `.sheet`: it rises over the screen, full height, rounded at the
 * top, and the swipe down dismisses it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ShioriSheet(onDismiss: () -> Unit, content: @Composable ColumnScope.(dismiss: () -> Unit) -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val dismiss: () -> Unit = { scope.launch { state.hide() }.invokeOnCompletion { onDismiss() } }
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = state,
        containerColor = Shiori.colors.groupedBackground,
        shape = RoundedCornerShape(topStart = 38.dp, topEnd = 38.dp),
        dragHandle = null,
        contentWindowInsets = { WindowInsets(0) },
    ) {
        Column(Modifier.fillMaxWidth().statusBarsPadding()) { content(dismiss) }
    }
}

/** A full-screen cover, as SwiftUI's `.fullScreenCover`: no swipe, its own close button. */
@Composable
fun FullScreenCover(onDismiss: () -> Unit, content: @Composable () -> Unit) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false, decorFitsSystemWindows = false),
    ) {
        Box(Modifier.fillMaxSize().background(Shiori.colors.background)) { content() }
    }
}

/**
 * A sheet's navigation bar: the leading button (close), a centred title, the trailing button
 * (confirm), as an iOS 26 sheet draws them.
 */
@Composable
fun SheetBar(
    title: String? = null,
    leading: @Composable RowScope.() -> Unit = {},
    trailing: @Composable RowScope.() -> Unit = {},
) {
    Box(Modifier.fillMaxWidth().height(64.dp).padding(horizontal = 16.dp)) {
        Row(Modifier.align(Alignment.CenterStart), horizontalArrangement = Arrangement.spacedBy(8.dp), content = leading)
        if (title != null) {
            Text(
                title,
                style = Shiori.type.headline,
                color = Shiori.colors.label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center,
                modifier = Modifier.align(Alignment.Center).padding(horizontal = 64.dp),
            )
        }
        Row(Modifier.align(Alignment.CenterEnd), horizontalArrangement = Arrangement.spacedBy(8.dp), content = trailing)
    }
}

/** `.alert`: a title, a message and an OK. */
@Composable
fun ShioriAlert(
    title: String,
    message: String?,
    onDismiss: () -> Unit,
    confirm: String = L("OK"),
    dismissLabel: String? = null,
    destructive: Boolean = false,
    onConfirm: () -> Unit = onDismiss,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title, style = Shiori.type.headline) },
        text = message?.let { { Text(it, style = Shiori.type.subheadline) } },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(confirm, color = if (destructive) Shiori.colors.red else Shiori.colors.accent)
            }
        },
        dismissButton = dismissLabel?.let { { TextButton(onClick = onDismiss) { Text(it, color = Shiori.colors.accent) } } },
        containerColor = Shiori.colors.secondaryGroupedBackground,
    )
}

@Composable
fun HSpacer(width: androidx.compose.ui.unit.Dp) = Spacer(Modifier.width(width))
