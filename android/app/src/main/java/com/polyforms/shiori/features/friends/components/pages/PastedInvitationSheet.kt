package com.polyforms.shiori.features.friends.components.pages

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.actionLabelStyle
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ContentPaste
import androidx.compose.material3.LocalContentColor
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/** Everything the pasted-invitation sheet can ask for. */
enum class PastedInvitationAction { PASTE, LATER }

/**
 * The invitation a new reader brought from the web page, when Google Play carried none: the page
 * copied the link, and this sheet asks for it once, on the first opening. The clipboard is read
 * only when the reader presses "Coller", never unasked.
 */
@Composable
fun PastedInvitationSheet(onAction: (PastedInvitationAction) -> Unit) {
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 28.dp).padding(top = 34.dp, bottom = 16.dp).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .size(76.dp)
                .clearAndSetSemantics {}
                .drawBehind {
                    val stroke = 1.5.dp.toPx()
                    drawCircle(
                        Color.White.copy(alpha = 0.4f),
                        radius = size.minDimension / 2 - stroke / 2,
                        center = Offset(size.width / 2, size.height / 2),
                        style = Stroke(stroke, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 4.dp.toPx()))),
                    )
                },
            contentAlignment = Alignment.Center,
        ) {
            Icon(Symbol("person.badge.plus"), null, Modifier.size(32.dp), tint = Shiori.colors.label)
        }
        Text(
            L("Une invitation vous attend"),
            style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold),
            color = Shiori.colors.label,
            modifier = Modifier.padding(top = 22.dp),
        )
        Text(
            L("Un ami vous a ouvert sa bibliothèque. Collez son lien pour voir ses livres, et qu'il voie les vôtres."),
            style = Shiori.type.subheadline,
            color = Shiori.colors.secondaryLabel,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 10.dp).widthIn(max = 300.dp),
        )
        ActionButton({ onAction(PastedInvitationAction.PASTE) }, Modifier.padding(top = 30.dp).defaultMinSize(minWidth = 150.dp), height = 50.dp) {
            // The system's own paste icon: Android has no paste button of its own to borrow.
            Icon(Icons.Outlined.ContentPaste, null, Modifier.size(20.dp), tint = LocalContentColor.current)
            Text(L("Coller"), style = actionLabelStyle(50.dp), color = LocalContentColor.current, maxLines = 1)
        }
        Text(
            L("Plus tard"),
            style = Shiori.type.subheadline,
            color = Shiori.colors.secondaryLabel,
            modifier = Modifier.padding(top = 14.dp).defaultMinSize(minHeight = 44.dp).plainClickable { onAction(PastedInvitationAction.LATER) }.padding(top = 12.dp),
        )
    }
}

@Preview(showBackground = true)
@Composable
private fun PastedInvitationSheetPreview() = PreviewSurface(dark = true) {
    PastedInvitationSheet {}
}
