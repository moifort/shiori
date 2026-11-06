package com.polyforms.shiori.features.discover.components.organisms

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.features.authors.personInitials
import com.polyforms.shiori.features.discover.AuthorNewsItem
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwardWinner
import com.polyforms.shiori.features.discover.DiscoveriesLine
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.ReleaseSection
import com.polyforms.shiori.features.discover.SagaDiscovery
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.caption
import com.polyforms.shiori.features.discover.cover
import com.polyforms.shiori.features.discover.isComing
import com.polyforms.shiori.features.friends.LovedAuthor
import com.polyforms.shiori.features.friends.LovedBook
import com.polyforms.shiori.features.friends.LovedSaga
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.components.atoms.CoverBadge
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.CoverTile
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.color
import com.polyforms.shiori.shared.components.styles.plainClickable

@Composable
fun AwaitedEditionTile(edition: AwaitedEdition, width: Dp = 84.dp, onTap: () -> Unit) =
    CoverTile(edition.cover, edition.caption, Modifier.plainClickable(onClick = onTap), width, edition.stateTint?.color())

@Composable
fun AwardWinnerTile(winner: AwardWinner, width: Dp = 84.dp, onTap: () -> Unit) =
    CoverTile(winner.cover, winner.caption, Modifier.plainClickable(onClick = onTap), width)

/** The flame on what many friends love. */
@Composable
fun LovedByManyBadge(modifier: Modifier = Modifier) {
    Box(
        modifier.size(22.dp).background(Shiori.colors.orange, CircleShape).border(1.5.dp, Shiori.colors.background, CircleShape),
        contentAlignment = Alignment.Center,
    ) { Icon(Symbol("flame.fill"), L("Adoré par vos amis"), Modifier.size(12.dp), tint = Color.White) }
}

@Composable
fun LovedBookTile(loved: LovedBook, width: Dp = 84.dp, onTap: () -> Unit) {
    Box(Modifier.plainClickable(onClick = onTap)) {
        CoverTile(loved.book.book, loved.lovers.caption, width = width)
        if (loved.lovers.lovedByMany) LovedByManyBadge(Modifier.offset((-6).dp, (-6).dp))
    }
}

/** A saga's volume just out or announced, its date under it, green or orange. */
@Composable
fun SeriesNewsTile(opened: DiscoveryVolume, width: Dp = 84.dp, onTap: () -> Unit) =
    CoverTile(opened.cover, opened.caption, Modifier.plainClickable(onClick = onTap), width, if (opened.isComing) Shiori.colors.orange else Shiori.colors.green)

@Composable
fun SeriesNewsStrip(volumes: List<DiscoveryVolume>, onTap: (DiscoveryVolume) -> Unit) {
    LazyRow(contentPadding = PaddingValues(16.dp, 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        items(volumes, key = { it.id }) { SeriesNewsTile(it) { onTap(it) } }
    }
}

/** A strip of what the friends hearted, one row that scrolls sideways. */
@Composable
fun LovedSagasStrip(sagas: List<LovedSaga>, onTap: (LovedSaga) -> Unit) {
    val colors = Shiori.colors
    LazyRow(contentPadding = PaddingValues(16.dp, 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        items(sagas, key = { it.id }) { loved ->
            Box(Modifier.plainClickable { onTap(loved) }) {
                Column(Modifier.width(84.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    loved.saga.volumes.firstOrNull()?.let { BookCover(it, 84.dp, formatBadgeSize = 22.dp) }
                    Text(loved.saga.name, style = Shiori.type.caption.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(if (loved.saga.ownedCount == 1) L("1 tome") else L("%lld tomes", loved.saga.ownedCount), style = Shiori.type.caption2, color = colors.secondaryLabel)
                    Text(loved.lovers.caption, style = Shiori.type.caption2, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
                if (loved.lovers.lovedByMany) LovedByManyBadge(Modifier.offset((-6).dp, (-6).dp))
            }
        }
    }
}

@Composable
fun LovedAuthorsStrip(authors: List<LovedAuthor>, onTap: (LovedAuthor) -> Unit) {
    val colors = Shiori.colors
    LazyRow(contentPadding = PaddingValues(16.dp, 12.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.Top) {
        items(authors, key = { it.id }) { loved ->
            Column(Modifier.width(84.dp).plainClickable { onTap(loved) }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Box {
                    AuthorAvatar(personInitials(loved.name), loved.portraitURL, size = 64.dp)
                    if (loved.lovers.lovedByMany) LovedByManyBadge(Modifier.align(Alignment.TopEnd).offset(4.dp, (-4).dp))
                }
                Text(loved.name, style = Shiori.type.caption.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2, textAlign = TextAlign.Center)
                Text(loved.lovers.caption, style = Shiori.type.caption2, color = colors.secondaryLabel, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** A suggestion as the discoveries line opens on it: its cover, and why, in a few words. */
@Composable
fun DiscoverySuggestionRow(suggestion: Suggestion, onTap: () -> Unit) {
    val colors = Shiori.colors
    val lead = suggestion.leadReference
    Row(Modifier.fillMaxWidth().plainClickable(onClick = onTap), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        BookCover(suggestion.cover, 56.dp)
        Text(
            buildAnnotatedString {
                val (mark, tint) = when {
                    lead == null -> "✦" to colors.purple
                    lead.favorite -> "♥" to colors.red
                    else -> "★" to colors.yellow
                }
                withStyle(SpanStyle(color = tint)) { append(mark) }
                append(" ")
                withStyle(SpanStyle(color = colors.label, fontWeight = FontWeight.Bold)) { append(suggestion.short) }
                append(" — ")
                append(suggestion.reason)
            },
            style = Shiori.type.footnote,
            color = colors.secondaryLabel,
            maxLines = 5,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f),
        )
    }
}

/** The month's discoveries: the first two in words, the others as covers. */
@Composable
fun DiscoveriesSummaryRow(line: DiscoveriesLine, width: Dp, onOpen: (Suggestion) -> Unit) {
    val purple = Shiori.colors.purple
    when (line) {
        is DiscoveriesLine.Shown -> {
            val first = line.discoveries.suggestions.take(2)
            val rest = line.discoveries.suggestions.drop(2)
            DiscoverSummaryRow(
                line.discoveries.title,
                L("D’après vos préférences"),
                symbol = "sparkles",
                tint = purple,
                lead = {
                    Column(Modifier.padding(horizontal = 12.dp).padding(top = 8.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        first.forEachIndexed { index, suggestion ->
                            if (index > 0) ShioriDivider(Modifier.padding(start = 68.dp))
                            DiscoverySuggestionRow(suggestion) { onOpen(suggestion) }
                        }
                        if (rest.isNotEmpty()) ShioriDivider()
                    }
                },
                covers = if (rest.isEmpty()) null else ({ items(rest, key = { it.id }) { s -> CoverTile(s.cover, "", Modifier.plainClickable { onOpen(s) }, width) } }),
            )
        }
        is DiscoveriesLine.Searching -> {
            val pulse by rememberInfiniteTransition(label = "searching").animateFloat(0.45f, 1f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "pulse")
            DiscoverSummaryRow(MonthlyDiscoveries.title(line.month), L("Recherche de vos découvertes…"), symbol = "sparkles", tint = purple) {
                items(5) { Box(Modifier.width(width).height(width * 1.5f).alpha(pulse).background(Shiori.colors.tertiaryFill, RoundedCornerShape(4.dp))) }
            }
        }
        is DiscoveriesLine.RanOut -> DiscoverSummaryRow(line.discoveries.title, line.discoveries.nextLine, symbol = "sparkles", tint = purple)
    }
}

/** What a saga row of Découvrir says under it: the volumes out, or the next one coming. */
@Composable
fun SagaReleasesSummary(row: SagaDiscovery, section: ReleaseSection) {
    val line = when (section) {
        ReleaseSection.UPCOMING -> row.releases.next?.let { L("À venir : Tome %lld", it.number) }
        ReleaseSection.RECENT -> if (row.missing.isEmpty()) null else L("Disponible : Tome %@", row.missing.joinToString(", "))
    }
    if (line != null) Text(line, style = Shiori.type.footnote.copy(fontWeight = FontWeight.Medium), color = Shiori.colors.orange, maxLines = 2)
}

/** An author's news as covers, each with a clock or a plus, its date under it. */
@Composable
fun AuthorWorksStrip(items: List<AuthorNewsItem>, author: String, onTap: (AuthorNewsItem) -> Unit) {
    val colors = Shiori.colors
    LazyRow(contentPadding = PaddingValues(top = 6.dp, end = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
        items(items, key = { it.id }) { work ->
            Column(Modifier.plainClickable { onTap(work) }, verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Box {
                    BookCover(
                        Book(id = "release-${work.id}", title = work.title, authors = listOf(author), format = if (work.isAudio) BookFormat.AUDIOBOOK else BookFormat.BOOK, coverURL = work.coverURL, status = ReadingStatus.TO_READ),
                        44.dp,
                        showsFormatBadge = false,
                    )
                    Box(Modifier.align(Alignment.TopEnd).offset(5.dp, (-5).dp)) {
                        CoverBadge(if (work.isComing) "clock" else "plus", if (work.isComing) colors.orange else colors.accent)
                    }
                }
                Text(
                    work.date?.let(ReleaseDateText::short) ?: "",
                    style = Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                    color = if (work.isComing) colors.orange else colors.secondaryLabel,
                    maxLines = 1,
                    softWrap = false,
                )
            }
        }
    }
}

@Composable
fun AuthorReleasesSummary(items: List<AuthorNewsItem>, section: ReleaseSection) {
    val first = items.firstOrNull() ?: return
    val line = when (section) {
        ReleaseSection.UPCOMING -> first.date?.let { L("À venir : %@ · %@", first.title, ReleaseDateText.short(it)) } ?: L("À venir : %@", first.title)
        ReleaseSection.RECENT -> L("Disponible : %@", first.title)
    }
    Text(line, style = Shiori.type.footnote.copy(fontWeight = FontWeight.Medium), color = Shiori.colors.orange, maxLines = 1, overflow = TextOverflow.Ellipsis)
}

/** The first look: everything followed is being looked up on the web, a line at a time. */
@Composable
fun FirstLookProgress() {
    val lines = listOf(
        L("On interroge les libraires"),
        L("On secoue les éditeurs"),
        L("On fouille sous les tables de nouveautés"),
        L("On demande aux sirènes si elles ont lu la suite"),
        L("On traverse la forêt des manuscrits"),
        L("On réveille le bibliothécaire"),
        L("On époussette les couvertures"),
    )
    var line by androidx.compose.runtime.remember { androidx.compose.runtime.mutableIntStateOf(0) }
    androidx.compose.runtime.LaunchedEffect(Unit) {
        while (true) {
            kotlinx.coroutines.delay(3_200)
            line = (line + 1) % lines.size
        }
    }
    Box(Modifier.fillMaxSize().padding(horizontal = 32.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(28.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(26.dp)) {
                listOf("mountain.2.fill", "water.waves", "sailboat.fill", "tree.fill", "books.vertical.fill").forEach {
                    Icon(Symbol(it), null, Modifier.size(30.dp), tint = Shiori.colors.accent)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Text(L("On retourne terre et mer…"), style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Shiori.colors.label, textAlign = TextAlign.Center)
                androidx.compose.animation.AnimatedContent(line, label = "line") {
                    Text(lines[it], style = Shiori.type.body, color = Shiori.colors.secondaryLabel, textAlign = TextAlign.Center)
                }
            }
            Text(
                L("La première visite peut prendre jusqu'à une minute et demie. Les suivantes s'ouvrent aussitôt."),
                style = Shiori.type.footnote,
                color = Shiori.colors.tertiaryLabel,
                textAlign = TextAlign.Center,
            )
        }
    }
}
