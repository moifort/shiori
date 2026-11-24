package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.ui.layout.layout
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameMillis
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.R
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.ListeningProgressLine
import com.polyforms.shiori.shared.book.ReadingPageLine
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.DownloadedTag
import com.polyforms.shiori.features.listening.ListeningButtonState
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionFill
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.ActionSize
import com.polyforms.shiori.shared.components.molecules.Figure
import com.polyforms.shiori.shared.components.molecules.Figures
import com.polyforms.shiori.shared.components.molecules.FiguresLine
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.coverGround
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import java.text.NumberFormat
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** The year's figures under the Home's hero: read, loved, to read, pages, hours. */
@Composable
fun HomeFiguresLine(
    year: Int,
    readCount: Int,
    favoriteCount: Int,
    toReadCount: Int,
    pagesRead: Int,
    hoursListened: Int,
    showsPagesAtZero: Boolean,
    modifier: Modifier = Modifier,
    onTap: () -> Unit,
) {
    val number = NumberFormat.getIntegerInstance()
    val items = buildList {
        add(Figure(number.format(readCount), L("lus en %@", year.toString())))
        add(Figure(number.format(favoriteCount), L("favoris")))
        add(Figure(number.format(toReadCount), L("à lire")))
        if (pagesRead > 0 || showsPagesAtZero) add(Figure(Figures.compact(pagesRead), L("pages")))
        if (hoursListened > 0) add(Figure("${number.format(hoursListened)}h", L("écoutées")))
    }
    Box(modifier.plainClickable(onClick = onTap)) { FiguresLine(items) }
}

/** A white capsule button of a card over a cover: the main action, small. */
@Composable
fun CardProminentButton(title: String, symbol: String?, onClick: () -> Unit) {
    ActionButton(onClick, size = ActionSize.SMALL) { ActionLabel(title, symbol, ActionSize.SMALL.side) }
}

/** A glass capsule button of a card over a cover, small. */
@Composable
fun CardGlassButton(title: String, onClick: () -> Unit) {
    ActionButton(onClick, fill = ActionFill.GLASS, size = ActionSize.SMALL) { ActionLabel(title, null, ActionSize.SMALL.side) }
}


/** A book under way, as the Home's reading rail shows it: its cover's wash, where the reader is. */
@Composable
fun ReadingFeatureCard(
    book: Book,
    caption: String,
    modifier: Modifier = Modifier,
    onOpen: () -> Unit,
    onFinish: () -> Unit,
    onProgress: () -> Unit,
    onOpenSeries: (() -> Unit)?,
    /** The play button of an Audible audiobook, once the player is built: it takes the place of "Marquer lu". */
    listening: ListeningButtonState? = null,
    onListen: () -> Unit = {},
    /** An Audible title kept on the phone: a download symbol tagged after "Audio". */
    isDownloaded: Boolean = false,
) {
    val series = book.series
    val overline = when {
        series == null -> book.authorLine
        series.volume == null -> series.name
        else -> "${series.name} · ${L("Tome %lld", series.volume)}"
    }
    val length = book.durationLabel ?: book.pageCount?.let { L("%lld pages", it) }
    Box(modifier.clip(RoundedCornerShape(18.dp)).height(IntrinsicSize.Min)) {
        CoverBackdrop(book.coverURL, Modifier.matchParentSize(), ground = Color.Transparent, tint = book.coverGround(true))
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.width(96.dp).fillMaxHeight().plainClickable(onClick = onOpen)) {
                BookCover(book, 96.dp, Modifier.fillMaxSize(), showsFormatBadge = false, cornerRadius = 0.dp, minHeight = 144.dp)
            }
            Column(Modifier.weight(1f).padding(top = 14.dp, bottom = 14.dp, end = 14.dp)) {
                Column(Modifier.fillMaxWidth().plainClickable(onClick = onOpen)) {
                    Text(overline, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.8f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Text(book.title, style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Row(Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            listOfNotNull(caption, length).joinToString(" · "),
                            style = Shiori.type.caption,
                            color = Color.White.copy(alpha = 0.75f),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f, fill = false),
                        )
                        CoverTags(book)
                        if (isDownloaded) DownloadedTag()
                    }
                    Box(Modifier.padding(top = 8.dp)) {
                        val progress = book.listeningProgress
                        val page = book.unfinishedReadingPage
                        when {
                            progress != null -> ListeningProgressLine(progress, book.durationMinutes)
                            page != null -> ReadingPageLine(page, book.pageCount)
                            else -> Spacer(Modifier.height(16.dp))
                        }
                    }
                }
                Spacer(Modifier.height(12.dp).weight(1f))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (listening != null) {
                        CardProminentButton(listening.title, listening.symbol, onListen)
                    } else if (book.tracksPages) {
                        CardProminentButton(L("Progression"), "bookmark.fill", onProgress)
                    } else {
                        CardProminentButton(L("Marquer lu"), "checkmark", onFinish)
                    }
                    if (onOpenSeries != null) CardGlassButton(L("Voir la série"), onOpenSeries)
                }
            }
        }
    }
}

/** As tall as its parent plus `rise`, drawn from `rise` above it: a hero's wash up under the bar and the figures. */
private fun Modifier.risingAbove(rise: androidx.compose.ui.unit.Dp): Modifier = layout { measurable, constraints ->
    val up = rise.roundToPx()
    val placeable = measurable.measure(androidx.compose.ui.unit.Constraints.fixed(constraints.maxWidth, constraints.maxHeight + up))
    layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, -up) }
}

/** The Home of an empty library: three blank covers and the scan button. */
@Composable
fun HomeEmptyHero(onScan: () -> Unit) {
    Box(Modifier.fillMaxWidth()) {
        // The wash runs up under the bar and down past the hero, taking no room of its own.
        Box(Modifier.matchParentSize()) { Box(
            Modifier.risingAbove(180.dp)
                .background(
                    Brush.radialGradient(
                        listOf(Color(0.42f, 0.16f, 0.11f), Color(0.23f, 0.11f, 0.16f), Color(0.05f, 0.07f, 0.09f)),
                        center = Offset(320f, 500f),
                        radius = 1400f,
                    ),
                ),
        ) }
        Box(Modifier.matchParentSize().background(Brush.verticalGradient(0.6f to Color.Transparent, 1f to Shiori.colors.groupedBackground)))
        Column(
            Modifier.fillMaxWidth().padding(start = 28.dp, end = 28.dp, bottom = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            DoneStack("camera.fill", Modifier.padding(top = 26.dp).size(150.dp, 188.dp), scale = 1f, coverSize = 122.dp to 180.dp)
            Text(
                L("Votre bibliothèque commence ici"),
                style = Shiori.type.title.copy(fontWeight = FontWeight.Bold),
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 24.dp),
            )
            Text(L("Une photo de la couverture suffit"), style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.85f), modifier = Modifier.padding(top = 4.dp))
            ActionButton(onScan, Modifier.padding(top = 20.dp).width(220.dp), size = ActionSize.EXTRA_LARGE) {
                ActionLabel(L("Scanner un livre"), "camera.fill", ActionSize.LARGE.side)
            }
        }
    }
}

/** The Home while the month's discoveries are being chosen: a turning ring over the wash. */
@Composable
fun HomeSearchingHero(month: String, bookCount: Int, backdropCover: String?) {
    var angle by remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameMillis { it }
        while (true) withFrameMillis { angle = ((it - start) / 1000f * 240f) % 360f }
    }
    Box(Modifier.fillMaxWidth()) {
        Box(Modifier.matchParentSize()) {
            CoverBackdrop(backdropCover, Modifier.risingAbove(180.dp), fadeHeight = 240.dp)
        }
        Column(Modifier.fillMaxWidth().padding(start = 28.dp, end = 28.dp, bottom = 44.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.padding(top = 26.dp).size(140.dp, 206.dp), contentAlignment = Alignment.Center) {
                val colors = listOf(
                    Color.Transparent,
                    Color(0.6f, 0.42f, 1f).copy(alpha = 0.5f),
                    Color(0.32f, 0.68f, 1f),
                    Color(1f, 0.42f, 0.68f),
                    Color(1f, 0.62f, 0.3f),
                )
                listOf(Triple(14.dp, 12.dp, 0.85f), Triple(6.dp, 4.dp, 0.9f), Triple(2.5.dp, 0.dp, 1f)).forEach { (width, blur, alpha) ->
                    Canvas(Modifier.size(64.dp).rotate(angle).blur(blur)) {
                        drawArc(
                            Brush.sweepGradient(colors),
                            startAngle = 0.08f * 360f,
                            sweepAngle = 0.7f * 360f,
                            useCenter = false,
                            alpha = alpha,
                            style = Stroke(width.toPx(), cap = StrokeCap.Round),
                        )
                    }
                }
            }
            Text(
                MonthlyDiscoveries.badge(month),
                style = Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
                modifier = Modifier.padding(top = 18.dp).background(Color.White.copy(alpha = 0.16f), CircleShape).padding(horizontal = 10.dp, vertical = 4.dp),
            )
            Text(
                MonthlyDiscoveries.arrivingTitle(month),
                style = Shiori.type.title.copy(fontWeight = FontWeight.Bold),
                color = Color.White,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 10.dp),
            )
            Text(L("D’après vos %lld livres", bookCount), style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.85f), modifier = Modifier.padding(top = 6.dp))
        }
    }
}

/** A card of the empty Home: a mark, a title, a line, and its buttons, on a tinted dark ground. */
@Composable
private fun StartCard(mark: @Composable () -> Unit, title: String, text: String, tint: Color, modifier: Modifier = Modifier, buttons: @Composable () -> Unit) {
    val shape = RoundedCornerShape(18.dp)
    Column(
        modifier.clip(shape).background(Color(0xFF1C1C1C)).background(Brush.linearGradient(listOf(tint.copy(alpha = 0.28f), Color(0xFF1C1C1C))))
            .border(1.dp, Color.White.copy(alpha = 0.1f), shape).padding(16.dp),
    ) {
        Box(Modifier.size(44.dp)) { mark() }
        Text(title, style = Shiori.type.headline, color = Color.White, modifier = Modifier.padding(top = 12.dp))
        Text(text, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.7f), modifier = Modifier.padding(top = 4.dp))
        Box(Modifier.padding(top = 14.dp)) { buttons() }
    }
}

/** Audible and Kindle, side by side, each with its connect button. */
@Composable
fun ImportSourcesRow(onConnect: (ImportSource) -> Unit) {
    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        ImportSource.entries.forEach { source ->
            val tint = if (source == ImportSource.AUDIBLE) Color(0.97f, 0.6f, 0.11f) else Color(0.34f, 0.71f, 0.91f)
            StartCard(
                {
                    // The service's logo in the card's colour, on a glass tile.
                    Box(
                        Modifier.fillMaxSize().background(Color.White.copy(alpha = 0.1f), RoundedCornerShape(12.dp)).border(1.dp, Color.White.copy(alpha = 0.14f), RoundedCornerShape(12.dp)),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(painterResource(if (source == ImportSource.AUDIBLE) R.drawable.logo_audible else R.drawable.logo_kindle), null, Modifier.size(26.dp), tint = tint)
                    }
                },
                source.label,
                if (source == ImportSource.AUDIBLE) L("Vos livres audio, avec leur avancement.") else L("Vos livres lus et en cours, marqués comme tels."),
                tint,
                Modifier.weight(1f),
            ) { CardProminentButton(L("Connecter"), null) { onConnect(source) } }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun HomeCardsPreview() = PreviewSurface {
    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        HomeFiguresLine(2026, 18, 15, 27, 41_230, 212, showsPagesAtZero = false) {}
        ReadingFeatureCard(DebugFixtures.reading[0], "Commencé il y a 12 jours", onOpen = {}, onFinish = {}, onProgress = {}, onOpenSeries = {})
        ReadingFeatureCard(
            DebugFixtures.reading[0].copy(format = com.polyforms.shiori.shared.BookFormat.AUDIOBOOK, durationMinutes = 1310, listeningProgress = 46, audibleAsin = "B0"),
            "depuis 2j",
            onOpen = {}, onFinish = {}, onProgress = {}, onOpenSeries = {},
            listening = ListeningButtonState.RESUME,
            isDownloaded = true,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            CardProminentButton("Terminé", "checkmark") {}
            CardGlassButton("Page") {}
        }
        ImportSourcesRow {}
    }
}
