package com.polyforms.shiori.shared.components.molecules

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A row of a link list: an icon, a title, a chevron, 50 high. */
@Composable
fun LinkRow(symbol: String, title: String, action: () -> Unit) {
    val colors = Shiori.colors
    Row(
        Modifier.fillMaxWidth().height(50.dp).clickable(onClick = action).padding(horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Symbol(symbol), null, Modifier.width(26.dp).size(22.dp), tint = colors.secondaryLabel)
        Text(title, style = Shiori.type.body, color = colors.label, modifier = Modifier.weight(1f))
        Icon(Symbol("chevron.right"), null, Modifier.size(18.dp), tint = colors.tertiaryLabel)
    }
}

/** Link rows on one white card, 20 from the edges. */
@Composable
fun LinkRowGroup(content: @Composable ColumnScope.() -> Unit) {
    Column(
        Modifier
            .padding(horizontal = 20.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(Shiori.colors.secondaryGroupedBackground),
        content = content,
    )
}

/** The spinner at the foot of a list, which asks for the next page as it appears. */
@Composable
fun LoadMoreRow(failed: Boolean, loadingLabel: String, onLoadMore: suspend () -> Unit) {
    val scope = rememberCoroutineScope()
    Box(Modifier.fillMaxWidth().padding(vertical = 12.dp), contentAlignment = Alignment.Center) {
        if (failed) {
            ShioriButton(L("Réessayer"), symbol = "arrow.clockwise", kind = ButtonKind.PLAIN) { onLoadMore() }
        } else {
            CircularProgressIndicator(Modifier.size(22.dp), strokeWidth = 2.dp)
            LaunchedEffect(Unit) { scope.launch { onLoadMore() } }
        }
    }
}

/** `LabeledContent` with an icon: a title on the left, the value on the right, copyable. */
@Composable
fun LabeledInfoRow(title: String, value: String, icon: String) {
    val colors = Shiori.colors
    val clipboard = LocalClipboardManager.current
    Row(
        Modifier.fillMaxWidth().clickable { clipboard.setText(AnnotatedString(value)) }.padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Symbol(icon), null, Modifier.size(20.dp), tint = colors.secondaryLabel)
        Text(title, style = Shiori.type.body, color = colors.label)
        Spacer(Modifier.weight(1f))
        Text(value, style = Shiori.type.body, color = colors.secondaryLabel, textAlign = TextAlign.End)
    }
}

/** "Série  Red Rising ›": the row that opens a book's saga. */
@Composable
fun SeriesLinkRow(name: String, action: () -> Unit) {
    val colors = Shiori.colors
    Row(
        Modifier.fillMaxWidth().clickable(onClick = action).padding(horizontal = 16.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Icon(Symbol("square.stack"), null, Modifier.size(20.dp), tint = colors.secondaryLabel)
        Text(L("Série"), style = Shiori.type.body, color = colors.label)
        Spacer(Modifier.weight(1f))
        Text(name, style = Shiori.type.body, color = colors.accent, textAlign = TextAlign.End)
        Icon(Symbol("chevron.right"), null, Modifier.size(14.dp), tint = colors.accent)
    }
}

enum class RowHeaderStyle { TRAILING, INLINE }

/** A section's title, with a detail or a chevron that opens the whole list. */
@Composable
fun RowHeader(
    title: String,
    modifier: Modifier = Modifier,
    detail: String? = null,
    style: RowHeaderStyle = RowHeaderStyle.TRAILING,
    action: (() -> Unit)? = null,
) {
    val colors = Shiori.colors
    when (style) {
        RowHeaderStyle.INLINE -> Row(
            modifier.then(if (action != null) Modifier.plainClickable(onClick = action) else Modifier),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(5.dp),
        ) {
            Text(title, style = Shiori.type.title2, color = colors.label)
            if (action != null) Icon(Symbol("chevron.right"), null, Modifier.size(22.dp), tint = colors.secondaryLabel)
        }
        RowHeaderStyle.TRAILING -> Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Text(title, style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = colors.label, modifier = Modifier.weight(1f))
            if (action != null) {
                Row(
                    Modifier.plainClickable(onClick = action),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(3.dp),
                ) {
                    if (detail != null) Text(detail, style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    Icon(Symbol("chevron.right"), null, Modifier.size(14.dp), tint = colors.secondaryLabel)
                }
            } else if (detail != null) {
                Text(detail, style = Shiori.type.subheadline, color = colors.secondaryLabel)
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun RowsPreview() = PreviewSurface {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        RowHeader("À lire", detail = "27", action = {})
        LinkRowGroup {
            LinkRow("person.2", "Auteurs") {}
            SeriesLinkRow("Frieren") {}
        }
        LabeledInfoRow("Éditeur", "Folio", "building.columns")
        LoadMoreRow(failed = true, loadingLabel = "Chargement…") {}
    }
}
