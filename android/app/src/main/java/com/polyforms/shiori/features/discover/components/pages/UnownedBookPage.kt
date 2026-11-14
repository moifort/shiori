package com.polyforms.shiori.features.discover.components.pages

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.R
import com.polyforms.shiori.features.book.components.pages.HeroButton
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.FactLink
import com.polyforms.shiori.shared.book.FactTile
import com.polyforms.shiori.shared.book.SeriesVolumesRow
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.ConfirmationChoice
import com.polyforms.shiori.shared.platform.ConfirmationSheet
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Where a book the reader does not hold is sold: Audible for a recording, Amazon otherwise. */
data class UnownedBookStore(val url: String, val isAudible: Boolean) {
    val logo: Int get() = if (isAudible) R.drawable.audible_logo else R.drawable.amazon_logo
    val factLink: FactLink
        get() = if (isAudible) FactLink("audible", L("Écouter sur Audible"), logo, url) else FactLink("amazon", L("Voir sur Amazon"), logo, url)
}

/** What the bell asks before it is silenced. */
data class BellConfirmation(val title: String, val message: String, val action: String)

/**
 * A book that is not in the reader's library — announced, out or awaited — as its page draws it
 * everywhere: the hero over the cover's colours with the store, the "+" once it is out and the
 * bell, then the summary, the saga and the facts.
 */
@Composable
fun UnownedBookPage(
    book: Book,
    releaseDate: String?,
    store: UnownedBookStore?,
    isAlerted: Boolean,
    onToggleBell: () -> Unit,
    bellConfirmation: BellConfirmation? = null,
    state: BookState? = null,
    isOut: Boolean? = null,
    isAdded: Boolean? = null,
    leadingTiles: List<FactTile> = emptyList(),
    sagaName: String? = null,
    sagaVolumes: List<SeriesStripItem> = emptyList(),
    currentVolumeId: String? = null,
    isDescribing: Boolean = false,
    onAdd: suspend () -> Unit = {},
    onOpenSaga: () -> Unit = {},
    onOpenVolume: (Book) -> Unit = {},
) {
    val scope = rememberCoroutineScope()
    val uri = LocalUriHandler.current
    var confirmsSilence by remember { mutableStateOf(false) }
    var adding by remember { mutableStateOf(false) }
    val isUpcoming = isOut?.let { !it } ?: (releaseDate?.let { ReleaseDateText.isUpcoming(it) } ?: true)
    // The "+" only once the book is out: a book to come is followed, not shelved.
    val offeredAddition = if (isUpcoming) null else isAdded
    Column(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).verticalScroll(rememberScrollState())) {
        BookHero(book, state = state, showsLength = false, releaseDate = releaseDate, countdown = releaseDate?.let { ReleaseDateText.countdown(it) }) {
            Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                if (store != null) {
                    HeroButton(null, null, prominent = true, content = {
                        Text(if (isUpcoming) L("Précommander") else L("Commander"), style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = Color.Black, maxLines = 1)
                        Image(painterResource(store.logo), null, Modifier.width(if (store.isAudible) 30.dp else 44.dp).height(16.dp))
                    }) { uri.openUri(store.url) }
                }
                if (offeredAddition != null) {
                    Box(Modifier.alpha(if (offeredAddition) 0.6f else 1f)) {
                        HeroButton(null, if (offeredAddition) "checkmark" else "plus", content = if (adding) ({ CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp) }) else null) {
                            if (offeredAddition || adding) return@HeroButton
                            adding = true
                            scope.launch {
                                onAdd()
                                adding = false
                            }
                        }
                    }
                }
                HeroButton(null, if (isAlerted) "bell" else "bell.slash") {
                    if (isAlerted && bellConfirmation != null) confirmsSilence = true else onToggleBell()
                }
            }
        }
        Column(Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp), verticalArrangement = Arrangement.spacedBy(28.dp)) {
            if (!isDescribing) book.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
            if (sagaName != null && sagaVolumes.isNotEmpty()) {
                // The volume shown stands in the strip where the saga lacks it.
                val number = book.series?.volume
                val volumes = if (currentVolumeId != null || number == null) sagaVolumes else sagaVolumes.map { item ->
                    if (item is SeriesStripItem.Missing && item.number == number) SeriesStripItem.Owned(book) else item
                }
                SeriesVolumesRow(sagaName, volumes, currentVolumeId ?: book.id, onOpenSaga, onOpenVolume)
            }
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Informations"))
                val tiles = book.readOnlyFactTiles.map { tile ->
                    if (tile.id == "firstPublishedIn" && releaseDate != null) tile.copy(value = ReleaseDateText.full(releaseDate)) else tile
                }
                FactGrid(listOf(FactGroup(leadingTiles + tiles)), listOfNotNull(store?.factLink))
            }
        }
    }
    if (confirmsSilence && bellConfirmation != null) {
        ConfirmationSheet(
            bellConfirmation.title,
            listOf(ConfirmationChoice(bellConfirmation.action, destructive = true) { onToggleBell() }),
            bellConfirmation.message,
        ) { confirmsSilence = false }
    }
}

@Preview(showBackground = true)
@Composable
private fun UnownedBookPagePreview() = PreviewSurface {
    UnownedBookPage(
        DebugFixtures.reading[2].copy(title = "Frieren 16"),
        releaseDate = DebugFixtures.announcedVolume.date,
        store = null,
        isAlerted = true,
        onToggleBell = {},
        sagaName = "Frieren",
    )
}
