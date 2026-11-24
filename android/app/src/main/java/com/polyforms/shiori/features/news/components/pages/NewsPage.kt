package com.polyforms.shiori.features.news.components.pages

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.interaction.DragInteraction
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.asPaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.layout.layout
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.AwardMention
import com.polyforms.shiori.features.discover.LiteraryAward
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.library.LibraryDestination
import com.polyforms.shiori.features.news.FeedEventKind
import com.polyforms.shiori.features.news.FriendMove
import com.polyforms.shiori.features.news.NewsAgenda
import com.polyforms.shiori.features.news.NewsAgendaDay
import com.polyforms.shiori.features.news.NewsCard
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.NewsPersonTarget
import com.polyforms.shiori.features.news.NewsShelfItem
import com.polyforms.shiori.features.news.NewsShelves
import com.polyforms.shiori.features.news.NewsWishes
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.ReleasedItem
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.features.news.components.organisms.DarkCards
import com.polyforms.shiori.features.news.components.organisms.NewsCardButtons
import com.polyforms.shiori.features.news.components.organisms.NewsLargeCard
import com.polyforms.shiori.features.news.components.organisms.NewsLargeCardMetrics
import com.polyforms.shiori.features.news.components.organisms.NewsPersonTile
import com.polyforms.shiori.features.news.components.organisms.NewsSeriesRail
import com.polyforms.shiori.features.news.components.organisms.NewsShelf
import com.polyforms.shiori.features.news.components.organisms.NewsShelfHeader
import com.polyforms.shiori.features.news.components.organisms.NewsWishesRail
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.ToolbarIconButton
import com.polyforms.shiori.shared.components.atoms.setAsideAnimation
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.coverGround
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.components.styles.saturation
import com.polyforms.shiori.shared.platform.ScrollAwayBar
import com.polyforms.shiori.shared.platform.rememberScrollAwayState
import kotlinx.coroutines.launch
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.TextStyle as DateStyle
import java.time.temporal.ChronoUnit
import java.util.Locale

/** Everything the Découvrir page can ask for. */
sealed interface NewsAction {
    /** A card's book, on the page the rest of the app opens it on. */
    data class Open(val card: NewsCard) : NewsAction

    /** "Envies": the card's book onto the wish list. */
    data class Wish(val card: NewsCard) : NewsAction

    /** "Dans vos envies" tapped again: off the wish list. */
    data class Unwish(val card: NewsCard) : NewsAction

    /** "Pas intéressé" on a discovery or a prize: black and white. */
    data class Dismiss(val card: NewsCard) : NewsAction

    /** The eye pressed again, or the greyed "+ Ajouter": in colour again. */
    data class Reconsider(val card: NewsCard) : NewsAction

    /** A card's capsule pressed: what its "+ Ajouter" did is taken back. */
    data class Undo(val card: NewsCard, val isWished: Boolean) : NewsAction

    /** The "+" of a large card: onto the pile or among the books read, in the format given. */
    data class Add(val card: NewsCard, val status: CopiedStatus, val format: BookFormat) : NewsAction

    /** The "+" of a large card: the edition in the phone's language awaited. */
    data class AwaitEdition(val card: NewsCard, val format: ReleaseFormat) : NewsAction

    /** A rail's title: the Library view that answers it, already filtered. */
    data class OpenLibrary(val destination: LibraryDestination) : NewsAction

    /** A large card's pill: the friend on the Amis tab, alone, or the author's or narrator's page. */
    data class OpenPerson(val target: NewsPersonTarget) : NewsAction
    data object OpenAlerts : NewsAction
    data object Refresh : NewsAction
}

/**
 * The Découvrir tab, pure: an agenda of what the book world brought the reader. At the top "À la
 * une", the friends' coups de cœur and the releases of what the reader follows, out in the last
 * twenty days or due in the next thirty; then a strip of the days that bring something, each with
 * a dot per piece of news, over every day's covers in one rail the strip follows; then what each
 * friend did last, the friends' coups de cœur, the year's prizes one winner a page, and a shelf
 * per follow. Every rail is left out when empty.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewsPage(
    agenda: NewsAgenda,
    wished: NewsWishes = NewsWishes(),
    isLoading: Boolean,
    errorMessage: String?,
    alertsSilenced: Boolean,
    onAction: suspend (NewsAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val act: (NewsAction) -> Unit = { action -> scope.launch { onAction(action) } }
    val bar = rememberScrollAwayState()
    val colors = Shiori.colors
    // The first day whose covers are on the agenda's rail.
    var lead by remember { mutableStateOf<LocalDate?>(null) }
    var refreshing by remember { mutableStateOf(false) }
    Box(Modifier.fillMaxSize().background(colors.background).nestedScroll(bar.connection)) {
        when {
            errorMessage != null && agenda.isEmpty && !isLoading -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                FailureState(L("Actualité indisponible"), errorMessage) { onAction(NewsAction.Refresh) }
            }
            isLoading && agenda.isEmpty -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
            agenda.isEmpty -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                EmptyState("sparkles", L("Rien de neuf pour l'instant"), L("Cette page se remplit toute seule à partir de votre bibliothèque et de vos amis."))
            }
            else -> PullToRefreshBox(
                refreshing,
                onRefresh = {
                    refreshing = true
                    scope.launch {
                        onAction(NewsAction.Refresh)
                        refreshing = false
                    }
                },
                Modifier.fillMaxSize(),
            ) {
                Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(bottom = 120.dp)) {
                    val day = agenda.days.firstOrNull { it.day == (lead ?: agenda.openingDay) }
                    val top = WindowInsets.statusBars.asPaddingValues().calculateTopPadding() + 64.dp
                    DarkCards {
                        Box(Modifier.fillMaxWidth()) {
                            // The first cover's colours run up under the title and fade into the page.
                            CoverBackdrop(
                                (agenda.headlines.firstOrNull()?.card ?: day?.cards?.firstOrNull())?.cover?.coverURL,
                                Modifier.matchParentSize().layout { measurable, constraints ->
                                    val height = 760.dp.roundToPx()
                                    val placeable = measurable.measure(constraints.copy(minHeight = height, maxHeight = height))
                                    layout(constraints.maxWidth, constraints.maxHeight) { placeable.place(0, (top - 300.dp).roundToPx()) }
                                },
                                fadeHeight = 160.dp,
                                ground = colors.background,
                            )
                            Column(Modifier.padding(top = top)) {
                                if (agenda.headlines.isNotEmpty()) {
                                    Box(Modifier.padding(bottom = 30.dp)) { NewsShelf(L("À la une"), agenda.headlines, wished = wished, onAction = act) }
                                }
                                if (agenda.days.isNotEmpty()) {
                                    NewsAgendaSection(agenda.days, agenda.today, agenda.openingDay, { lead = it }, wished, act)
                                }
                            }
                        }
                    }
                    Shelves(agenda, wished, act)
                }
            }
        }
        DarkCards {
            ScrollAwayBar(L("Actualité"), bar) {
                ToolbarIconButton(L("Notifications"), if (alertsSilenced) "bell.slash" else "bell") { act(NewsAction.OpenAlerts) }
            }
        }
    }
}

/** The friends, the prizes, then a rail per follow, each left out when it holds nothing. */
@Composable
private fun Shelves(agenda: NewsAgenda, wished: NewsWishes, act: (NewsAction) -> Unit) {
    val shelves = agenda.shelves
    val gap = Modifier.padding(top = 30.dp)
    if (shelves.activity.isNotEmpty()) Box(gap) { NewsShelf(L("Activité des amis"), shelves.activity, wished = wished, onAction = act) }
    if (shelves.loves.isNotEmpty()) Box(gap) { NewsShelf(L("Coups de cœur des amis"), shelves.loves, wished = wished, onAction = act) }
    if (agenda.prizes.isNotEmpty()) Box(gap) { NewsPrizesSlider(agenda.prizes, wished, act) }
    if (shelves.series.isNotEmpty()) Box(gap) { NewsSeriesRail(shelves.series, act) }
    if (shelves.authors.isNotEmpty()) {
        Box(gap) { NewsShelf(L("Auteurs préférés"), shelves.authors, { act(NewsAction.OpenLibrary(LibraryDestination.Authors)) }, wished, act) }
    }
    if (shelves.narrators.isNotEmpty()) {
        Box(gap) { NewsShelf(L("Narrateurs préférés"), shelves.narrators, { act(NewsAction.OpenLibrary(LibraryDestination.Narrators)) }, wished, act) }
    }
    if (shelves.wishes.isNotEmpty()) {
        Box(gap) {
            if (shelves.wishes.size <= NewsLargeCardMetrics.CARD_LIMIT) {
                NewsShelf(L("Liste d'envies"), shelves.wishes, { act(NewsAction.OpenLibrary(LibraryDestination.Wishlist)) }, wished, act)
            } else {
                NewsWishesRail(shelves.wishes, act)
            }
        }
    }
}

// L'agenda

private data class AgendaEntry(val id: String, val day: LocalDate, val item: NewsShelfItem)

/** Every day's covers in a row, each keyed by its day so a card news on two days keeps two places. */
private fun entries(days: List<NewsAgendaDay>): List<AgendaEntry> =
    days.flatMap { day -> day.cards.map { AgendaEntry("${day.day}~${it.id}", day.day, NewsShelves.item(it)) } }

/**
 * The agenda: its title, the strip of the days that bring something — the month over the first
 * leaf of each, a dot under each leaf for its news — and under the strip every day's covers in one
 * rail, oldest first. The rail opens on the opening day's covers; as it scrolls, the days whose
 * covers are on screen turn white in the strip, which follows it; a leaf brings the rail to its day.
 */
@Composable
fun NewsAgendaSection(
    days: List<NewsAgendaDay>,
    today: LocalDate,
    opening: LocalDate?,
    onLead: (LocalDate?) -> Unit,
    wished: NewsWishes = NewsWishes(),
    onAction: (NewsAction) -> Unit,
) {
    val entries = remember(days) { entries(days) }
    val scope = rememberCoroutineScope()
    val strip = rememberLazyListState()
    val rail = rememberLazyListState()
    // The days whose covers are on screen.
    var shown by remember { mutableStateOf(setOfNotNull(opening)) }
    // Whether the rail has been moved by the reader: until then it rests on the opening day.
    var isMoved by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        val day = opening ?: return@LaunchedEffect
        onLead(day)
        days.indexOfFirst { it.day == day }.takeIf { it >= 0 }?.let { strip.scrollToItem(it) }
        entries.indexOfFirst { it.day == day }.takeIf { it >= 0 }?.let { rail.scrollToItem(it) }
    }
    LaunchedEffect(rail) {
        rail.interactionSource.interactions.collect { if (it is DragInteraction.Start) isMoved = true }
    }
    LaunchedEffect(rail, entries) {
        snapshotFlow {
            val info = rail.layoutInfo
            val start = info.viewportStartOffset
            val end = info.viewportEndOffset
            info.visibleItemsInfo.filter { item ->
                val visible = minOf(item.offset + item.size, end) - maxOf(item.offset, start)
                visible * 2 >= item.size
            }.mapNotNull { entries.getOrNull(it.index)?.day }.toSet()
        }.collect { onScreen ->
            if (!isMoved || onScreen.isEmpty() || onScreen == shown) return@collect
            shown = onScreen
            val first = onScreen.min()
            onLead(first)
            days.indexOfFirst { it.day == first }.takeIf { it >= 0 }?.let { strip.animateScrollToItem(it) }
        }
    }
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(L("L'agenda"), Modifier.padding(horizontal = 20.dp), style = Shiori.type.title2, color = Color.White)
        LazyRow(state = strip, contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            itemsIndexed(days, key = { _, it -> it.day.toString() }) { index, day ->
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        if (opensMonth(index, days)) month(day.day) else " ",
                        Modifier.width(45.dp),
                        style = TextStyle(fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 0.6.sp),
                        color = Color.White.copy(alpha = 0.6f),
                        maxLines = 1,
                        softWrap = false,
                    )
                    NewsDayLeaf(day, day.day == today, day.day in shown) {
                        val index = entries.indexOfFirst { it.day == day.day }
                        if (index >= 0) {
                            isMoved = true
                            scope.launch { rail.animateScrollToItem(index) }
                        }
                    }
                }
            }
        }
        BoxWithConstraints(Modifier.fillMaxWidth().padding(top = 4.dp)) {
            val large = entries.size <= NewsLargeCardMetrics.CARD_LIMIT
            val width = NewsLargeCardMetrics.railWidth(maxWidth - 40.dp, entries.size)
            val height = NewsLargeCardMetrics.height(entries.map { it.item })
            LazyRow(
                state = rail,
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(if (large) 12.dp else 13.dp),
                flingBehavior = rememberSnapFlingBehavior(rail),
            ) {
                items(entries, key = { it.id }) { entry ->
                    if (large) {
                        NewsLargeCard(entry.item, Modifier.width(width), wished.isWished(entry.item), wished, height, onAction)
                    } else {
                        NewsPersonTile(entry.item) { onAction(NewsAction.Open(entry.item.card)) }
                    }
                }
            }
        }
    }
}

/** Whether the leaf at `index` is the first of its month. */
private fun opensMonth(index: Int, days: List<NewsAgendaDay>): Boolean =
    index == 0 || days[index].day.withDayOfMonth(1) != days[index - 1].day.withDayOfMonth(1)

/** "NOV.", over the month's first leaf. */
private fun month(day: LocalDate): String = day.month.getDisplayName(DateStyle.SHORT, Locale.getDefault()).uppercase(Locale.getDefault())

/** "3 nouvelles", "1 nouvelle", for TalkBack on the strip's leaf. */
private fun count(day: NewsAgendaDay): String = if (day.cards.size == 1) L("1 nouvelle") else L("%lld nouvelles", day.cards.size)

/** One day of the strip: its weekday over its number on a light glass ringed in white, a dot per news. */
@Composable
private fun NewsDayLeaf(day: NewsAgendaDay, isToday: Boolean, isPicked: Boolean, onPick: () -> Unit) {
    val locale = Locale.getDefault()
    val shape = RoundedCornerShape(12.dp)
    val spoken = day.day.format(DateTimeFormatter.ofPattern("EEEE d MMMM", locale)) + ", " + count(day)
    Column(
        Modifier.plainClickable(onClick = onPick).semantics {
            contentDescription = spoken
            selected = isPicked
        },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Column(
            Modifier
                .size(45.dp, 58.dp)
                .background(if (isPicked) Color.White else Color.White.copy(alpha = 0.12f), shape)
                .border(if (isToday) 1.5.dp else 1.dp, Color.White.copy(alpha = if (isPicked) 0f else if (isToday) 1f else 0.34f), shape),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                day.day.dayOfWeek.getDisplayName(DateStyle.SHORT, locale).replace(".", "").uppercase(locale),
                style = TextStyle(fontSize = 10.sp, fontWeight = FontWeight.SemiBold),
                color = if (isPicked) Color.Black.copy(alpha = 0.6f) else Color.White.copy(alpha = 0.8f),
            )
            Text(day.day.dayOfMonth.toString(), style = Shiori.type.headline.copy(fontWeight = FontWeight.Bold), color = if (isPicked) Color.Black else Color.White)
        }
        Row(Modifier.height(5.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            repeat(minOf(day.cards.size, 3)) { Box(Modifier.size(5.dp).background(Color.White, CircleShape)) }
        }
    }
}

/**
 * A day's first news, large: its cover edge to edge on the leading side, over the cover's own
 * colours the emblem of what brought it — the prize between its laurels, the friend, the follow —
 * the title, the author, and at the foot the large cards' buttons.
 */
@Composable
private fun NewsAgendaLead(card: NewsCard, modifier: Modifier, isWished: Boolean, wishes: NewsWishes, onAction: (NewsAction) -> Unit) {
    val turnedDown = wishes.isTurnedDown(card)
    val saturation by animateFloatAsState(if (turnedDown) 0f else 1f, setAsideAnimation(), label = "turnedDown")
    val cover = card.cover
    val height = NewsLargeCardMetrics.height
    Box(
        modifier
            .height(height)
            .clip(RoundedCornerShape(18.dp))
            .saturation(saturation)
            .plainClickable { onAction(NewsAction.Open(card)) }
            .semantics { contentDescription = cover.title },
    ) {
        CoverBackdrop(cover.coverURL, Modifier.matchParentSize(), ground = Color.Transparent, tint = cover.coverGround(true))
        Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
            Box(Modifier.width(NewsLargeCardMetrics.coverWidth).fillMaxHeight()) {
                BookCover(cover, NewsLargeCardMetrics.coverWidth, showsFormatBadge = false, minHeight = height, cornerRadius = 0.dp)
            }
            Column(Modifier.weight(1f).padding(top = 14.dp, bottom = 14.dp, end = 14.dp)) {
                NewsCardEmblem(card)
                Text(cover.authors.joinToString(", "), Modifier.padding(top = 4.dp), style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.8f), maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text(cover.title, style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold), color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.weight(1f).height(8.dp))
                NewsCardButtons(card, isWished, wishes, onAction)
            }
        }
    }
}

/** What brought a card, over its title: the prize between its laurels — both, when it won two — or the kicker. */
@Composable
private fun NewsCardEmblem(card: NewsCard) {
    if (card is NewsCard.Award && card.winner.mentions.isNotEmpty()) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { card.winner.mentions.take(2).forEach { CompactLaurels(it) } }
    } else {
        NewsCardKicker(card, KickerStyle.FICHE)
    }
}

/** The small emblem of a prize a card wears over its title: the laurels around its name and year. */
@Composable
private fun CompactLaurels(mention: AwardMention) {
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol("laurel.leading"), null, Modifier.size(24.dp), tint = Color.White)
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(mention.award.shortName.uppercase(), style = TextStyle(fontSize = 9.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp), color = Color.White, maxLines = 1)
            Text(mention.year.toString(), style = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.ExtraBold), color = Color.White, maxLines = 1)
            Text(categoryName(mention.award), style = TextStyle(fontSize = 10.sp), color = Color.White.copy(alpha = 0.85f), maxLines = 1)
        }
        Icon(Symbol("laurel.trailing"), null, Modifier.size(24.dp), tint = Color.White)
    }
}

/** What the prize crowns, under its year. */
private fun categoryName(award: LiteraryAward): String = when (award) {
    LiteraryAward.LOCUS_SCIENCE_FICTION -> L("Meilleur roman de SF")
    LiteraryAward.LOCUS_FANTASY -> L("Meilleur roman de fantasy")
    else -> L("Meilleur roman")
}

// Prix de l'année

/**
 * The year's prizes, one winner a page: the day's large card, the prize between its laurels,
 * "+ Ajouter" and the closed eye; the next card peeks at the edge.
 */
@Composable
fun NewsPrizesSlider(cards: List<NewsCard>, wished: NewsWishes = NewsWishes(), onAction: (NewsAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        NewsShelfHeader(L("Prix de l'année"))
        BoxWithConstraints(Modifier.fillMaxWidth()) {
            val width = NewsLargeCardMetrics.railWidth(maxWidth - 40.dp, cards.size)
            val state = rememberLazyListState()
            DarkCards {
                LazyRow(
                    state = state,
                    contentPadding = PaddingValues(horizontal = 20.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    flingBehavior = rememberSnapFlingBehavior(state),
                ) {
                    items(cards, key = { it.id }) { card -> NewsAgendaLead(card, Modifier.width(width), card.key in wished, wished, onAction) }
                }
            }
        }
    }
}

// The parts every card shares

/** `STORY`: on glass, under a carousel. `FICHE`: bare, over a story's title, its symbol in a disc. `TILE`: on a cover's foot. */
enum class KickerStyle { STORY, FICHE, TILE }

/** Who or what brought a card, in white: a friend's face and name, a prize between laurels, a release's day. */
@Composable
fun NewsCardKicker(card: NewsCard, style: KickerStyle) {
    val long = style != KickerStyle.TILE
    val text = if (style == KickerStyle.TILE) Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold) else Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold)
    Row(
        Modifier.height(if (style == KickerStyle.STORY) 30.dp else 25.dp),
        horizontalArrangement = Arrangement.spacedBy(if (style == KickerStyle.TILE) 4.dp else 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        when (card) {
            is NewsCard.Friend -> {
                val move = card.move
                Row(horizontalArrangement = Arrangement.spacedBy((-6).dp)) {
                    (listOf(move.lead) + move.others).take(if (style == KickerStyle.FICHE) 3 else 2).forEach {
                        AccountAvatarView(it.avatar, it.friendName, if (style == KickerStyle.TILE) 18.dp else 22.dp)
                    }
                }
                Text(NewsCardText.friend(move, long), style = text, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                if (move.lead.kind == FeedEventKind.LOVED) Icon(Symbol("heart.fill"), null, Modifier.size(11.dp), tint = Color.White)
            }
            is NewsCard.Award -> {
                Icon(Symbol("laurel.leading"), null, Modifier.size(14.dp), tint = Color.White)
                Text(NewsCardText.label(card, long), style = text, color = Color.White, maxLines = 1)
                Icon(Symbol("laurel.trailing"), null, Modifier.size(14.dp), tint = Color.White)
            }
            else -> {
                if (style == KickerStyle.FICHE) {
                    Box(Modifier.size(22.dp).background(Color.White.copy(alpha = 0.16f), CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Symbol(NewsCardText.symbol(card)), null, Modifier.size(11.dp), tint = Color.White)
                    }
                } else {
                    Icon(Symbol(NewsCardText.symbol(card)), null, Modifier.size(11.dp), tint = Color.White)
                }
                Text(NewsCardText.label(card, long), style = text, color = Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
    }
}

/** What a card says of itself, in words. */
object NewsCardText {
    /** The day over a story: "Aujourd'hui", "Hier", "Il y a 3 jours"; "À la une" for what has no day. */
    fun `when`(card: NewsCard, now: Instant = Instant.now()): String {
        val date = card.date ?: return L("À la une")
        val zone = ZoneId.systemDefault()
        val days = ChronoUnit.DAYS.between(date.atZone(zone).toLocalDate(), now.atZone(zone).toLocalDate())
        return when {
            days <= 0 -> L("Aujourd'hui")
            days == 1L -> L("Hier")
            else -> L("Il y a %lld jours", days)
        }
    }

    /** "Marc a adoré", "Sophie et Léa ont commencé"; on a tile, the names alone. */
    fun friend(move: FriendMove, long: Boolean): String {
        val names = (listOf(move.lead) + move.others).map { it.friendName }
        val who = if (names.size > 2) L("%@ et %lld autres", names[0], names.size - 1) else names.joinToString(L(" et "))
        if (!long) {
            val rating = move.lead.rating
            return if (move.lead.kind == FeedEventKind.FINISHED && rating != null && rating > 0) "$who ${UpcomingRelease.stars(rating)}" else who
        }
        val plural = names.size > 1
        return when (move.lead.kind) {
            FeedEventKind.LOVED -> if (plural) L("%@ ont adoré", who) else L("%@ a adoré", who)
            FeedEventKind.FINISHED -> if (plural) L("%@ ont terminé", who) else L("%@ a terminé", who)
            FeedEventKind.STARTED -> if (plural) L("%@ ont commencé", who) else L("%@ a commencé", who)
        }
    }

    fun symbol(card: NewsCard): String = when (card) {
        is NewsCard.Released -> when (val item = card.item) {
            is ReleasedItem.Release -> sourceSymbol(item.release.source)
            is ReleasedItem.Narrator -> "music.mic"
        }
        is NewsCard.Upcoming -> sourceSymbol(card.release.source)
        is NewsCard.Discovery -> "sparkles"
        is NewsCard.Award -> "laurel.leading"
        is NewsCard.Friend -> "person.2.fill"
    }

    private fun sourceSymbol(source: ReleaseSource) = when (source) {
        ReleaseSource.SAGA -> "books.vertical.fill"
        ReleaseSource.AUTHOR -> "person.fill"
        ReleaseSource.AWAITED -> "binoculars.fill"
        ReleaseSource.NARRATOR -> "music.mic"
    }

    /** The line beside the symbol. */
    fun label(card: NewsCard, long: Boolean, now: Instant = Instant.now()): String = when (card) {
        is NewsCard.Released -> when (val item = card.item) {
            is ReleasedItem.Release -> dayText(item.day, now).let { if (long) L("Sorti %@", it) else it }
            is ReleasedItem.Narrator -> if (long) L("%@ prête sa voix", item.news.narrator) else item.news.narrator
        }
        is NewsCard.Upcoming -> card.release.date?.let(::shortDate) ?: L("Annoncé")
        is NewsCard.Discovery -> card.suggestion.short
        is NewsCard.Award -> card.winner.mentions.firstOrNull()?.let {
            if (long) "${it.award.displayName} ${it.year}" else "${it.award.stripName} ${it.year}"
        } ?: ""
        is NewsCard.Friend -> friend(card.move, long)
    }

    /** The sentence under a story's cover, when the card has one to say. */
    fun reason(card: NewsCard): String? = when (card) {
        is NewsCard.Discovery -> card.suggestion.reason
        is NewsCard.Released -> (card.item as? ReleasedItem.Release)?.release?.reason?.takeIf { it.isNotEmpty() }
        is NewsCard.Upcoming -> card.release.reason.takeIf { it.isNotEmpty() }
        // Two prizes stand as two emblems over the title; a third is said.
        is NewsCard.Award -> if (card.winner.mentions.size > 2) card.winner.awardsLine else null
        else -> null
    }

    /** "aujourd'hui", "hier", "4 nov.". */
    private fun dayText(day: LocalDate, now: Instant): String {
        val today = now.atZone(ZoneId.systemDefault()).toLocalDate()
        return when (day) {
            today -> L("aujourd'hui")
            today.minusDays(1) -> L("hier")
            else -> day.format(DateTimeFormatter.ofPattern("d MMM", Locale.getDefault()))
        }
    }

    /** "12 déc.", "déc. 2026", "2027", from `YYYY-MM-DD`, `YYYY-MM` or `YYYY`. */
    private fun shortDate(date: String): String {
        val parts = date.split("-").mapNotNull { it.toIntOrNull() }
        val year = parts.firstOrNull() ?: return date
        if (parts.size < 2) return year.toString()
        val day = runCatching { LocalDate.of(year, parts[1], parts.getOrElse(2) { 1 }) }.getOrNull() ?: return year.toString()
        val pattern = if (parts.size > 2) "d MMM" else "MMM yyyy"
        return day.format(DateTimeFormatter.ofPattern(pattern, Locale.getDefault()))
    }
}

@Preview(showBackground = true, heightDp = 1800)
@Composable
private fun NewsPagePreview() = PreviewSurface(dark = true) {
    NewsPage(NewsFixtures.agenda(), isLoading = false, errorMessage = null, alertsSilenced = false) {}
}

@Preview(showBackground = true)
@Composable
private fun NewsPageThreeCardsPreview() = PreviewSurface(dark = true) {
    NewsPage(NewsFixtures.agenda().agendaOnly(3), isLoading = false, errorMessage = null, alertsSilenced = false) {}
}

@Preview(showBackground = true)
@Composable
private fun NewsPageEmptyPreview() = PreviewSurface {
    NewsPage(NewsAgenda.empty(), isLoading = false, errorMessage = null, alertsSilenced = false) {}
}

@Preview(showBackground = true)
@Composable
private fun NewsPageFailedPreview() = PreviewSurface {
    NewsPage(NewsAgenda.empty(), isLoading = false, errorMessage = "Le réseau est indisponible.", alertsSilenced = false) {}
}
