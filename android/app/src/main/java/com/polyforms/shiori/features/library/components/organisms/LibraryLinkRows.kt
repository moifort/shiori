package com.polyforms.shiori.features.library.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

enum class LibraryLink { BOOKS, SERIES, AUTHORS, NARRATORS, WISHLIST }

/** The Library's ways in: every book, the sagas, the authors, the narrators, the wishlist. */
@Composable
fun LibraryLinkRows(showsSeries: Boolean, showsAuthors: Boolean, showsNarrators: Boolean, onOpen: (LibraryLink) -> Unit) {
    Column(Modifier.padding(horizontal = 20.dp)) {
        LinkRow("book.pages", L("Livres")) { onOpen(LibraryLink.BOOKS) }
        if (showsSeries) LinkRow("square.stack", L("Séries")) { onOpen(LibraryLink.SERIES) }
        if (showsAuthors) LinkRow("author", L("Auteurs")) { onOpen(LibraryLink.AUTHORS) }
        if (showsNarrators) LinkRow("music.mic", L("Narrateurs")) { onOpen(LibraryLink.NARRATORS) }
        LinkRow("bookmark", L("Liste d'envies")) { onOpen(LibraryLink.WISHLIST) }
    }
}

@Composable
private fun LinkRow(symbol: String, title: String, onClick: () -> Unit) {
    val colors = Shiori.colors
    Box(Modifier.fillMaxWidth().height(52.dp).plainClickable(onClick = onClick)) {
        Row(Modifier.fillMaxWidth().align(Alignment.CenterStart), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(16.dp)) {
            Box(Modifier.width(28.dp), contentAlignment = Alignment.Center) { Icon(Symbol(symbol), null, Modifier.size(22.dp), tint = colors.label) }
            Text(title, style = Shiori.type.title3, color = colors.label, modifier = Modifier.weight(1f))
            Icon(Symbol("chevron.right"), null, Modifier.size(16.dp), tint = colors.tertiaryLabel)
            Spacer(Modifier.width(0.dp))
        }
        ShioriDivider(Modifier.align(Alignment.BottomStart).padding(start = 44.dp))
    }
}
