package com.polyforms.shiori.features.news.components.organisms

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.gestures.snapping.rememberSnapFlingBehavior
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.components.pages.bookAddMenu
import com.polyforms.shiori.features.news.NewsCard
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.NewsPersonTarget
import com.polyforms.shiori.features.news.NewsShelfItem
import com.polyforms.shiori.features.news.NewsWishes
import com.polyforms.shiori.features.news.components.pages.NewsAction
import com.polyforms.shiori.features.series.components.pages.takenAs
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.OutlinedTag
import com.polyforms.shiori.shared.components.atoms.setAsideAnimation
import com.polyforms.shiori.shared.components.molecules.AddMenuButton
import com.polyforms.shiori.shared.components.molecules.NotInterestedToggle
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.components.organisms.coverGround
import com.polyforms.shiori.shared.components.styles.DarkColors
import com.polyforms.shiori.shared.components.styles.LocalShioriColors
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.glass
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.components.styles.saturation

/** The large cards' measures, as the home's "En cours" card (ReadingFeatureCard). */
object NewsLargeCardMetrics {
    /** Every large card of Actualité stands at this height, whatever its title or its tags say. */
    val height = 149.dp

    /** What a person's pill adds over the text, so the title keeps its two lines. */
    val pillRoom = 18.dp

    /** The "En cours" card's cover width. */
    val coverWidth = 96.dp

    /** The calendar leaf's width and its margin, kept clear by the text. */
    val leafRoom = 58.dp

    /** How many books a shelf still draws as large cards. */
    const val CARD_LIMIT = 3

    /** A row's height: taller by the pill's room when one of its cards carries a pill. */
    fun height(items: List<NewsShelfItem>): Dp = if (items.any { it.pillName != null }) height + pillRoom else height

    /** A card's width in a rail: the page's, less the margins; narrower from two on, so the next peeks in. */
    fun railWidth(width: Dp, count: Int): Dp = if (count > 1) width - 50.dp else width
}

/** The dark scheme the cards draw in, over their covers' colours. */
@Composable
fun DarkCards(content: @Composable () -> Unit) = CompositionLocalProvider(LocalShioriColors provides DarkColors, content = content)

/**
 * A shelf of Découvrir under its title: up to three books, each as a large card, a lone one
 * across the page and the next one peeking in from two on; more than three, the rail of covers.
 */
@Composable
fun NewsShelf(title: String, items: List<NewsShelfItem>, onMore: (() -> Unit)? = null, wished: NewsWishes = NewsWishes(), onAction: (NewsAction) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        NewsShelfHeader(title, onMore)
        if (items.size <= NewsLargeCardMetrics.CARD_LIMIT) NewsCardRow(items, wished, onAction) else NewsTileRow(items, onAction)
    }
}

/** Large cards side by side, scrolling sideways: a lone card spans the page, the next one peeks in. */
@Composable
fun NewsCardRow(items: List<NewsShelfItem>, wished: NewsWishes = NewsWishes(), onAction: (NewsAction) -> Unit) {
    BoxWithConstraints(Modifier.fillMaxWidth()) {
        val width = NewsLargeCardMetrics.railWidth(maxWidth - 40.dp, items.size)
        val state = rememberLazyListState()
        DarkCards {
            LazyRow(
                state = state,
                contentPadding = PaddingValues(horizontal = 20.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                flingBehavior = rememberSnapFlingBehavior(state),
            ) {
                items(items, key = { it.id }) { item ->
                    NewsLargeCard(item, Modifier.width(width), wished.isWished(item), wished, NewsLargeCardMetrics.height(items), onAction)
                }
            }
        }
    }
}

/**
 * One book of a short shelf, large: its cover edge to edge on the leading side, what happened at
 * its foot; beside it the person it is shown for in a pill with a chevron, which opens them, then
 * the author, the title, the outlined tags — how long is left, "Audio", a foreign language — and
 * at the foot "+ Ajouter", or "Ajouté" for a book the reader holds already. A release's day sits
 * in the corner as a calendar leaf.
 */
@Composable
fun NewsLargeCard(
    item: NewsShelfItem,
    modifier: Modifier = Modifier,
    isWished: Boolean = false,
    wishes: NewsWishes = NewsWishes(),
    height: Dp = NewsLargeCardMetrics.height,
    onAction: (NewsAction) -> Unit,
) {
    val card = item.card
    val cover = card.cover
    val turnedDown = wishes.isTurnedDown(card)
    val saturation by animateFloatAsState(if (turnedDown) 0f else 1f, setAsideAnimation(), label = "turnedDown")
    val leaf = item.day
    val textEnd = if (leaf == null) 0.dp else NewsLargeCardMetrics.leafRoom
    val tags = buildList {
        if (cover.format == BookFormat.AUDIOBOOK) add(L("Audio"))
        leaf?.let { ReleaseDateText.countdown(it) }?.let(::add)
        cover.language?.takeIf { it.isForeign }?.let { add(it.code) }
    }
    val description = listOfNotNull(item.person, cover.title, item.word).joinToString(", ")
    DarkCards {
        Box(
            modifier
                .height(height)
                .clip(RoundedCornerShape(18.dp))
                .saturation(saturation)
                .plainClickable { onAction(NewsAction.Open(card)) }
                .semantics { contentDescription = description },
        ) {
            CoverBackdrop(cover.coverURL, Modifier.matchParentSize(), ground = Color.Transparent, tint = cover.coverGround(true))
            Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                PosterCover(
                    cover,
                    PosterLabel(item.word, rating = item.rating),
                    width = NewsLargeCardMetrics.coverWidth,
                    showsEditionTags = false,
                    // Edge to edge over the card's whole height, no rim: its own corners round it.
                    corner = 0.dp,
                    height = height,
                )
                Column(Modifier.weight(1f).padding(top = 14.dp, bottom = 14.dp, end = 14.dp)) {
                    if (item.pillName != null) {
                        Box(Modifier.padding(end = if (leaf == null) 0.dp else NewsLargeCardMetrics.leafRoom - 14.dp).padding(bottom = 7.dp).padding(top = 0.dp)) {
                            NewsPersonPill(item, isLarge = true) { onAction(NewsAction.OpenPerson(it)) }
                        }
                    }
                    Text(
                        cover.authors.joinToString(", "),
                        Modifier.padding(end = textEnd),
                        style = Shiori.type.subheadline,
                        color = Color.White.copy(alpha = 0.8f),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        cover.title,
                        Modifier.padding(end = textEnd),
                        style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold),
                        color = Color.White,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                    )
                    if (tags.isNotEmpty()) {
                        Row(Modifier.padding(top = 4.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            tags.forEach { OutlinedTag(it, isFrosted = false) }
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    NewsCardButtons(card, isWished, wishes, onAction)
                }
            }
            if (leaf != null) Box(Modifier.align(Alignment.TopEnd).padding(10.dp)) { ReleaseDateBadge(leaf, onGlass = true) }
        }
    }
}

/**
 * The foot of a large card: "+ Ajouter", the one button every book page shares, and for a prize
 * or a discovery the closed eye. Its menu offers each format the book may be taken in, the wish
 * list, then the editions to await; the action chosen is said in its place, a second tap taking it
 * back. The eye turns the card black and white; a second tap, or the greyed "+ Ajouter", brings
 * the colour back.
 */
@Composable
fun NewsCardButtons(card: NewsCard, isWished: Boolean = false, wishes: NewsWishes = NewsWishes(), onAction: (NewsAction) -> Unit) {
    val isTurnedDown = wishes.isTurnedDown(card)
    val done = wishes.state(card, isWished)
    // The formats the book may be taken in: none for a book not out yet, which the wish list holds.
    val formats = if (card is NewsCard.Upcoming) emptyList() else card.cover.format.takenAs
    // The editions that may be awaited: those the page of a discovery or a prize offers, otherwise
    // the one in the phone's language for a book read in another.
    val awaitable = when (card) {
        is NewsCard.Discovery -> card.suggestion.awaitableFormats
        is NewsCard.Award -> card.winner.awaitableFormats
        else -> if (card.cover.language?.isForeign == true) listOf(if (card.cover.format == BookFormat.AUDIOBOOK) ReleaseFormat.AUDIOBOOK else ReleaseFormat.BOOK) else emptyList()
    }
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        AddMenuButton(
            bookAddMenu(
                formats,
                owned = false,
                awaitable = awaitable,
                wished = false,
                onAdd = { status, format -> onAction(NewsAction.Add(card, status, format)) },
                onWish = { onAction(NewsAction.Wish(card)) },
                onAwait = { onAction(NewsAction.AwaitEdition(card, it)) },
            ),
            done = done,
            isTurnedDown = isTurnedDown,
            onReconsider = { onAction(NewsAction.Reconsider(card)) },
            onUndo = if (done == TakenState.Owned) null else ({ onAction(NewsAction.Undo(card, isWished)) }),
        )
        if (card.isDismissable) {
            val locked = done != null && !isTurnedDown
            NotInterestedToggle(isTurnedDown, Modifier.alpha(if (locked) 0.45f else 1f)) { turnDown ->
                if (!locked) onAction(if (turnDown) NewsAction.Dismiss(card) else NewsAction.Reconsider(card))
            }
        }
    }
}

/**
 * The person a cover is shown for — a friend's face and first name, an author's or a narrator's
 * portrait and "M. Wells" — in a white pill on glass.
 */
@Composable
fun NewsPersonPill(item: NewsShelfItem, isLarge: Boolean = false, maxWidth: Dp = Dp.Unspecified, onOpen: ((NewsPersonTarget) -> Unit)? = null) {
    val target = item.personTarget
    val avatarSize = if (isLarge) 22.dp else 18.dp
    val opens = isLarge && target != null && onOpen != null
    DarkCards {
        Row(
            Modifier
                .then(if (maxWidth != Dp.Unspecified) Modifier.widthIn(max = maxWidth) else Modifier)
                .height(if (isLarge) 28.dp else 26.dp)
                .glass(RoundedCornerShape(50))
                .then(if (opens) Modifier.plainClickable { onOpen?.invoke(target!!) } else Modifier)
                .padding(start = if (isLarge) 3.dp else 4.dp, end = if (isLarge) 10.dp else 9.dp),
            horizontalArrangement = Arrangement.spacedBy(if (isLarge) 6.dp else 5.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val avatar = item.avatar
            if (avatar != null) {
                AccountAvatarView(avatar, item.person, avatarSize)
            } else {
                AuthorAvatar(initials(item.person), item.portraitURL, size = avatarSize)
            }
            Text(
                item.pillName ?: "",
                Modifier.weight(1f, fill = false),
                style = if (isLarge) Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold) else Shiori.type.caption2.copy(fontWeight = FontWeight.SemiBold),
                color = Color.White,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            if (isLarge && target != null) Icon(Symbol("chevron.right"), null, Modifier.size(11.dp), tint = Color.White.copy(alpha = 0.75f))
        }
    }
}

/** "Martha Wells" → "MW", the monogram while no portrait is known. */
private fun initials(name: String?): String =
    (name ?: "").split(" ").filter { it.isNotEmpty() }.let { words -> listOfNotNull(words.firstOrNull(), words.drop(1).lastOrNull()) }
        .mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")

@Preview(showBackground = true)
@Composable
private fun NewsLargeCardPreview() = PreviewSurface(dark = true) {
    val shelves = NewsFixtures.agenda().shelves
    Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        (shelves.loves + shelves.series).take(3).forEach { NewsLargeCard(it, Modifier.fillMaxWidth()) {} }
    }
}
