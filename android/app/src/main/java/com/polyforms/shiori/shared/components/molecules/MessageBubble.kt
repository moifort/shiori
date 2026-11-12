package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.GenericShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** An iMessage bubble with its tail: blue on the right for the reader's own words. */
private fun bubbleShape(tailTrailing: Boolean) = GenericShape { size, _ ->
    val r = minOf(18f * 2.75f, size.height / 2)
    val tail = 6f * 2.75f
    val w = size.width
    val h = size.height
    fun x(v: Float) = if (tailTrailing) v else w - v
    moveTo(x(r), 0f)
    lineTo(x(w - r), 0f)
    quadraticTo(x(w), 0f, x(w), r)
    lineTo(x(w), h - r)
    cubicTo(x(w), h - r / 2, x(w + tail / 2), h - 2, x(w + tail), h)
    cubicTo(x(w), h + 1, x(w - r / 4), h, x(w - r / 2), h)
    lineTo(x(r), h)
    quadraticTo(x(0f), h, x(0f), h - r)
    lineTo(x(0f), r)
    quadraticTo(x(0f), 0f, x(r), 0f)
    close()
}

@Composable
fun MessageBubble(text: String, isMine: Boolean = false, sender: String? = null, action: (() -> Unit)? = null) {
    val colors = Shiori.colors
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        if (isMine) {
            Spacer(Modifier.weight(1f).width(48.dp))
        } else {
            Box(Modifier.size(28.dp).background(colors.gray, CircleShape), contentAlignment = Alignment.Center) {
                Text((sender?.take(1) ?: "?").uppercase(), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.White)
            }
        }
        Column(horizontalAlignment = if (isMine) Alignment.End else Alignment.Start, verticalArrangement = Arrangement.spacedBy(3.dp), modifier = Modifier.weight(4f, fill = false)) {
            if (!isMine && sender != null) {
                Text(sender, style = Shiori.type.caption, color = colors.secondaryLabel, modifier = Modifier.padding(start = 12.dp))
            }
            Text(
                text,
                style = Shiori.type.body,
                color = if (isMine) Color.White else colors.label,
                modifier = Modifier
                    .background(if (isMine) colors.blue else colors.fill, bubbleShape(isMine))
                    .then(if (action != null) Modifier.plainClickable(onClick = action) else Modifier)
                    .padding(horizontal = 14.dp, vertical = 8.dp),
            )
        }
        if (!isMine) Spacer(Modifier.weight(1f).width(48.dp))
    }
}

/** The bar a note is typed in, over the keyboard: cancel, the field, send. */
@Composable
fun MessageComposer(
    current: String?,
    onCancel: () -> Unit,
    onSend: (String?) -> Unit,
    placeholder: String = L("Commentaire"),
    maxLength: Int = Int.MAX_VALUE,
) {
    val colors = Shiori.colors
    var text by remember { mutableStateOf(current ?: "") }
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    val edited = text.trim().ifEmpty { null }
    val canSend = edited != current && (edited?.length ?: 0) <= maxLength
    Row(
        Modifier.fillMaxWidth().imePadding().padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(Modifier.size(40.dp).glass(CircleShape).plainClickable(onClick = onCancel), contentAlignment = Alignment.Center) {
            Icon(Symbol("xmark"), L("Annuler"), Modifier.size(18.dp), tint = colors.label)
        }
        Row(
            Modifier
                .weight(1f)
                .background(colors.background.copy(alpha = 0.9f), RoundedCornerShape(20.dp))
                .border(1.dp, colors.separator, RoundedCornerShape(20.dp))
                .padding(start = 14.dp, end = 4.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            Box(Modifier.weight(1f).padding(vertical = 9.dp)) {
                if (text.isEmpty()) Text(placeholder, style = Shiori.type.body, color = colors.tertiaryLabel)
                BasicTextField(
                    text,
                    { text = it },
                    Modifier.fillMaxWidth().heightIn(max = 140.dp).focusRequester(focus),
                    textStyle = Shiori.type.body.copy(color = colors.label),
                    cursorBrush = SolidColor(colors.accent),
                    maxLines = 6,
                )
            }
            Icon(
                Symbol("arrow.up.circle.fill"),
                L("Enregistrer"),
                Modifier.padding(bottom = 3.dp).size(32.dp).plainClickable(enabled = canSend) { onSend(edited) },
                tint = if (canSend) colors.blue else colors.tertiaryLabel,
            )
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun MessageBubblePreview() = PreviewSurface {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        MessageBubble("Le meilleur space opera que j'aie lu. Lis-le !", sender = "Léa")
        MessageBubble("Je le commence ce soir.", isMine = true)
        MessageComposer(current = null, onCancel = {}, onSend = {})
    }
}
