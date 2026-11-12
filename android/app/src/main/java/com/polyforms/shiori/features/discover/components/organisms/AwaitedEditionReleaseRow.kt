package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.color
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** An edition awaited: its cover, what it is, where it stands, the leaf of a day to come. */
@Composable
fun AwaitedEditionReleaseRow(edition: AwaitedEdition) {
    val colors = Shiori.colors
    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        BookCover(edition.cover)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(edition.format.awaitedTitle, style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold), color = colors.secondaryLabel)
            Text(edition.title, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2, overflow = TextOverflow.Ellipsis)
            if (edition.announcedDate == null) {
                Text(
                    edition.stateLine,
                    style = Shiori.type.subheadline.copy(fontWeight = FontWeight.Medium),
                    color = edition.stateTint?.color() ?: colors.secondaryLabel,
                )
            }
        }
        edition.announcedDate?.let { ReleaseDateBadge(it) }
    }
}

@Preview(showBackground = true)
@Composable
private fun AwaitedEditionReleaseRowPreview() = PreviewSurface {
    Column { DebugFixtures.discoverAwaited.forEach { AwaitedEditionReleaseRow(it) } }
}
