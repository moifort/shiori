package com.polyforms.shiori.features.friends.components.pages

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwaitedState
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.discover.components.organisms.AwaitedEditionReleaseRow
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.components.organisms.FriendBookAddMenu
import com.polyforms.shiori.features.friends.components.organisms.FriendCoverTag
import com.polyforms.shiori.shared.components.molecules.EditionWatch
import com.polyforms.shiori.shared.components.styles.glassOnDark
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.ui.Alignment
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.SystemTint
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.book.BookState
import com.polyforms.shiori.shared.book.BookSynopsisBlock
import com.polyforms.shiori.shared.book.FactGrid
import com.polyforms.shiori.shared.book.FactGroup
import com.polyforms.shiori.shared.book.PersonDestination
import com.polyforms.shiori.shared.SeriesStripItem
import com.polyforms.shiori.shared.book.SeriesVolumesRow
import com.polyforms.shiori.shared.book.readOnlyFactTiles
import com.polyforms.shiori.shared.book.storeFactLinks
import com.polyforms.shiori.shared.components.atoms.RatingStars
import com.polyforms.shiori.shared.components.molecules.MessageBubble
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.Locale
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Everything a friend's book page can ask for. */
sealed interface FriendBookAction {
    data object OpenSeries : FriendBookAction
    data class OpenAuthor(val author: PersonDestination) : FriendBookAction
    data class OpenNarrator(val narrator: PersonDestination) : FriendBookAction
    data class OpenAwaited(val edition: AwaitedEdition) : FriendBookAction
    data class StopAwaiting(val edition: AwaitedEdition) : FriendBookAction
    data class Add(val status: CopiedStatus, val format: BookFormat) : FriendBookAction
    data class AwaitEdition(val format: ReleaseFormat) : FriendBookAction
    data object Wish : FriendBookAction
}

/**
 * A friend's book page: the reader's own book page, read-only. The same hero — the friend named
 * on the detail line with where they stand, their name and avatar on a pill level with the cover's
 * top, the way onto the reader's shelf, the friend's "Coup de cœur" or else their stars on glass
 * beside it — then the summary, the facts, the editions awaited, the saga, their words.
 */
@Composable
fun FriendBookPage(
    entry: FriendBook,
    friendName: String,
    added: CopiedStatus?,
    awaited: List<AwaitedEdition>,
    formats: List<BookFormat> = emptyList(),
    awaitable: List<ReleaseFormat> = emptyList(),
    /** Every edition that may be awaited of it, awaited or not: what "+ Ajouter" says once one is. */
    awaitFormats: List<ReleaseFormat> = emptyList(),
    wished: Boolean = false,
    onAction: suspend (FriendBookAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: FriendBookAction) {
        scope.launch { onAction(action) }
    }
    val book = entry.book
    val owned = entry.inLibrary || added != null
    Column(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).verticalScroll(rememberScrollState())) {
        BookHero(
            book,
            state = friendState(book, friendName),
            showsLength = false,
            onOpenAuthor = { act(FriendBookAction.OpenAuthor(it)) },
            onOpenNarrator = { act(FriendBookAction.OpenNarrator(it)) },
            owner = {
                FriendCoverTag(friendName, entry.ownerAvatar, Modifier.semantics { contentDescription = L("Chez %@", friendName) }, isLarge = true)
            },
        ) {
            Row(
                Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                FriendBookAddMenu(
                    formats,
                    owned,
                    awaitable,
                    onAdd = { status, format -> act(FriendBookAction.Add(status, format)) },
                    onAwait = { act(FriendBookAction.AwaitEdition(it)) },
                    wished = wished,
                    onWish = { act(FriendBookAction.Wish) },
                    watch = EditionWatch(awaitFormats, awaited.map { it.format }.toSet()),
                    onStopAwaiting = { format -> awaited.firstOrNull { it.format == format }?.let { act(FriendBookAction.StopAwaiting(it)) } },
                )
                // One or the other: a heart is the top mark, so it stands in for the stars.
                val rating = book.rating
                if (book.favorite) {
                    // White, as every mark on glass, and said in words: the heart alone read as a
                    // button to heart it oneself.
                    GlassChip(L("Coup de cœur de %@", friendName)) {
                        Icon(Symbol("heart.fill"), null, Modifier.size(18.dp), tint = Color.White)
                        Text(L("Coup de cœur"), style = Shiori.type.headline, color = Color.White, maxLines = 1)
                    }
                } else if (rating != null) {
                    GlassChip(L("Noté %lld sur 5 par %@", rating.toInt(), friendName)) {
                        RatingStars(rating, size = 13.dp, monochrome = true, tint = Color.White)
                    }
                }
            }
        }
        Column(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 4.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            book.synopsis?.takeIf { it.isNotEmpty() }?.let { BookSynopsisBlock(it) }
            // What the book is; not the friend's days: the hero says when they read it.
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Informations"))
                FactGrid(listOf(FactGroup(book.readOnlyFactTiles)), book.storeFactLinks)
            }
            val found = awaited.filter { it.state != AwaitedState.UNANNOUNCED }
            if (found.isNotEmpty()) {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Éditions guettées"))
                    Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(16.dp)).background(Shiori.colors.secondaryGroupedBackground)) {
                        found.forEachIndexed { index, edition ->
                            var menu by remember { mutableStateOf(false) }
                            Box {
                                @OptIn(ExperimentalFoundationApi::class)
                                Box(
                                    Modifier
                                        .combinedClickable(onClick = { act(FriendBookAction.OpenAwaited(edition)) }, onLongClick = { menu = true })
                                        .padding(horizontal = 14.dp, vertical = 10.dp),
                                ) { AwaitedEditionReleaseRow(edition) }
                                MenuEntries(
                                    listOf(MenuEntry.Item(L("Ne plus suivre"), "bell.slash", destructive = true) { act(FriendBookAction.StopAwaiting(edition)) }),
                                    menu,
                                ) { menu = false }
                            }
                            if (index < found.lastIndex) ShioriDivider(Modifier.padding(start = 14.dp))
                        }
                    }
                }
            }
            // The saga under its own name, this volume alone: the others are one tap away.
            book.series?.let { membership ->
                SeriesVolumesRow(membership.name, listOf(SeriesStripItem.Owned(book)), book.id, { act(FriendBookAction.OpenSeries) }, {})
            }
            book.note?.takeIf { it.isNotEmpty() }?.let { note ->
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    RowHeader(L("Commentaires"))
                    MessageBubble(note, sender = friendName)
                }
            }
        }
    }
}

/** A fact on glass beside the hero's button, at the button's own height, nothing to tap. */
@Composable
private fun GlassChip(description: String, content: @Composable RowScope.() -> Unit) {
    Row(
        Modifier
            .defaultMinSize(52.dp, 52.dp)
            .glassOnDark(CircleShape)
            .padding(horizontal = 14.dp)
            .clearAndSetSemantics { contentDescription = description },
        horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally),
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

/**
 * Where the friend stands, said as a sentence about them: "Camille l'a lu le 15 octobre",
 * "Camille le lit depuis 3 jours", "Dans la pile de Camille" — heard for a recording.
 */
private fun friendState(book: Book, name: String, now: Instant = Instant.now()): BookState {
    val heard = book.format == BookFormat.AUDIOBOOK
    val zone = ZoneId.systemDefault()
    val (text, tint) = when (book.status) {
        ReadingStatus.READ -> {
            val finished = book.finishedAt
            val text = if (finished != null) {
                val date = finished.atZone(zone).toLocalDate()
                val day = "${date.dayOfMonth} ${date.month.getDisplayName(java.time.format.TextStyle.FULL, Locale.getDefault())}"
                if (heard) L("%@ l'a écouté le %@", name, day) else L("%@ l'a lu le %@", name, day)
            } else {
                if (heard) L("%@ l'a écouté", name) else L("%@ l'a lu", name)
            }
            text to SystemTint.GREEN
        }
        ReadingStatus.READING -> {
            val started = book.startedAt
            val text = if (started == null) {
                if (heard) L("%@ l'écoute en ce moment", name) else L("%@ le lit en ce moment", name)
            } else {
                val days = ChronoUnit.DAYS.between(started.atZone(zone).toLocalDate(), LocalDate.ofInstant(now, zone))
                when {
                    days <= 0 -> L("%@ l'a commencé aujourd'hui", name)
                    days == 1L -> if (heard) L("%@ l'écoute depuis hier", name) else L("%@ le lit depuis hier", name)
                    else -> if (heard) L("%@ l'écoute depuis %lld jours", name, days) else L("%@ le lit depuis %lld jours", name, days)
                }
            }
            text to SystemTint.BLUE
        }
        ReadingStatus.TO_READ -> L("Dans la pile de %@", name) to SystemTint.ORANGE
        ReadingStatus.DROPPED -> L("%@ l'a abandonné", name) to SystemTint.RED
    }
    return BookState(text, tint)
}

@Preview(showBackground = true)
@Composable
private fun FriendBookPagePreview() = PreviewSurface {
    FriendBookPage(
        DebugFixtures.friendBook,
        "Léa",
        added = null,
        awaited = emptyList(),
        formats = listOf(com.polyforms.shiori.shared.BookFormat.BOOK, com.polyforms.shiori.shared.BookFormat.AUDIOBOOK),
        awaitable = listOf(ReleaseFormat.AUDIOBOOK),
        awaitFormats = listOf(ReleaseFormat.AUDIOBOOK),
    ) {}
}
