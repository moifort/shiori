package com.polyforms.shiori.features.authors.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorWork
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.components.styles.ButtonKind
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriButton
import com.polyforms.shiori.shared.platform.ScreenBar
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** A book of an author's the reader does not hold: its cover, and a button to pile it. */
@Composable
fun AuthorWorkPage(work: AuthorWork, author: String, isAdding: Boolean, onAdd: suspend () -> Unit) {
    val colors = Shiori.colors
    Box(Modifier.fillMaxSize().background(colors.groupedBackground)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            Box(Modifier.fillMaxWidth()) {
                CoverBackdrop(work.coverURL, Modifier.fillMaxWidth().height(420.dp), fadeHeight = 140.dp)
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(16.dp)) {
                    PosterCover(
                        Book(id = "work-${work.id}", title = work.title, authors = listOf(author), coverURL = work.coverURL, status = ReadingStatus.TO_READ),
                        "",
                        Modifier.padding(top = 120.dp).shadow(20.dp, RoundedCornerShape(8.dp), spotColor = Color.Black.copy(alpha = 0.5f)),
                        width = 170.dp,
                    )
                    Column(Modifier.padding(horizontal = 24.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(work.title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = colors.label, textAlign = TextAlign.Center)
                        Text(work.publishedIn?.let { "$author · $it" } ?: author, style = Shiori.type.subheadline, color = colors.secondaryLabel)
                    }
                    ShioriButton(
                        L("Ajouter à ma pile"),
                        Modifier.padding(top = 8.dp).widthIn(max = 260.dp).fillMaxWidth(),
                        symbol = "plus",
                        kind = ButtonKind.PROMINENT,
                        enabled = !isAdding,
                        large = true,
                        action = onAdd,
                    )
                }
            }
        }
        ScreenBar()
    }
}

@Preview(showBackground = true)
@Composable
private fun AuthorWorkPagePreview() = PreviewSurface {
    AuthorWorkPage(DebugFixtures.authorPage.booksNotHeld[0], "Patrick Rothfuss", isAdding = false) {}
}
