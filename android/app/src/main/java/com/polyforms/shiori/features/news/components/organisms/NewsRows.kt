package com.polyforms.shiori.features.news.components.organisms

import android.text.format.DateUtils
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.features.friends.components.organisms.FriendMonogram
import com.polyforms.shiori.features.news.FeedEvent
import com.polyforms.shiori.features.news.FeedEventKind
import com.polyforms.shiori.features.news.FriendStory
import com.polyforms.shiori.features.news.ReleaseMonthSection
import com.polyforms.shiori.features.news.ReleaseSource
import com.polyforms.shiori.features.news.ReleasedItem
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.features.series.components.organisms.SeriesReleaseCard
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.CoverImage
import com.polyforms.shiori.shared.DiscoveredVolume
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.LMarkdown
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.coverTagsAreEmpty
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import androidx.compose.foundation.Canvas
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

private val coverHeight = 92.dp

/** A friend's move: their face, what they did and when, the book, a swipe to take it too. */
@Composable
fun FeedEventRow(
    event: FeedEvent,
    others: List<FeedEvent>,
    wished: Boolean,
    awaited: Boolean,
    onOpen: () -> Unit,
    onAdd: (CopiedStatus, BookFormat) -> Unit,
    onWish: () -> Unit,
    onAwait: (ReleaseFormat) -> Unit,
) {
    val colors = Shiori.colors
    val second = others.firstOrNull()
    val rest = others.size - 1
    val first = event.friendName
    val sentence = if (second == null) {
        when (event.kind) {
            FeedEventKind.LOVED -> LMarkdown("**%@** a adoré", first)
            FeedEventKind.FINISHED -> LMarkdown("**%@** a terminé", first)
            FeedEventKind.STARTED -> LMarkdown("**%@** a commencé", first)
        }
    } else {
        val other = second.friendName
        when (event.kind) {
            FeedEventKind.LOVED -> when (rest) {
                0 -> LMarkdown("**%@** et **%@** ont adoré", first, other)
                1 -> LMarkdown("**%@**, **%@** et 1 autre ont adoré", first, other)
                else -> LMarkdown("**%@**, **%@** et %lld autres ont adoré", first, other, rest)
            }
            FeedEventKind.FINISHED -> when (rest) {
                0 -> LMarkdown("**%@** et **%@** ont terminé", first, other)
                1 -> LMarkdown("**%@**, **%@** et 1 autre ont terminé", first, other)
                else -> LMarkdown("**%@**, **%@** et %lld autres ont terminé", first, other, rest)
            }
            FeedEventKind.STARTED -> when (rest) {
                0 -> LMarkdown("**%@** et **%@** ont commencé", first, other)
                1 -> LMarkdown("**%@**, **%@** et 1 autre ont commencé", first, other)
                else -> LMarkdown("**%@**, **%@** et %lld autres ont commencé", first, other, rest)
            }
        }
    }
    val time = DateUtils.getRelativeTimeSpanString(event.at.toEpochMilli(), System.currentTimeMillis(), DateUtils.MINUTE_IN_MILLIS, DateUtils.FORMAT_ABBREV_RELATIVE).toString()
    val stars = if (event.kind == FeedEventKind.FINISHED) event.rating?.takeIf { it > 0 }?.let(UpcomingRelease::stars) else null
    SwipeMenuBox(newsRowMenu(event.format, event.inLibrary, wished, awaited, onAdd, onWish, onAwait), onOpen) {
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).padding(horizontal = 20.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            BookCover(event.cover, 56.dp, Modifier.fillMaxHeight(), showsFormatBadge = false, minHeight = coverHeight)
            Column(Modifier.weight(1f).heightIn(min = coverHeight), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.padding(bottom = 1.dp)) {
                    Box {
                        AccountAvatarView(event.avatar, event.friendName, 20.dp)
                        if (second != null) {
                            Box(Modifier.offset(x = 13.dp).size(23.dp).background(colors.background, CircleShape).padding(1.5.dp)) {
                                AccountAvatarView(second.avatar, second.friendName, 20.dp)
                            }
                        }
                    }
                    if (second != null) Spacer(Modifier.width(13.dp))
                    Text(
                        androidx.compose.ui.text.buildAnnotatedString {
                            append(sentence)
                            append(" · " + time.replace(" ", "\u00A0"))
                        },
                        style = Shiori.type.footnote,
                        color = colors.secondaryLabel,
                    )
                }
                Text(event.title, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2, overflow = TextOverflow.Ellipsis)
                if (event.authors.isNotEmpty()) Text(event.authors.joinToString(", "), style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
                val audio = event.format == BookFormat.AUDIOBOOK
                if (stars != null || !coverTagsAreEmpty(event.language, audio)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        CoverTags(event.language, audio, isFrosted = false)
                        stars?.let { Text(it, style = Shiori.type.caption, color = colors.label) }
                    }
                }
            }
        }
    }
}

/** Something that came out: its cover, saga, title and author, who signed it. */
@Composable
fun ReleasedRow(
    item: ReleasedItem,
    owned: Boolean,
    wished: Boolean,
    awaited: Boolean,
    onOpen: (() -> Unit)?,
    onAdd: (CopiedStatus, BookFormat) -> Unit,
    onWish: () -> Unit,
    onAwait: (ReleaseFormat) -> Unit,
) {
    val colors = Shiori.colors
    SwipeMenuBox(newsRowMenu(item.format, owned, wished, awaited, onAdd, onWish, onAwait), onOpen) {
        Row(Modifier.fillMaxWidth().height(IntrinsicSize.Min).padding(horizontal = 20.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            BookCover(item.cover, 56.dp, Modifier.fillMaxHeight(), showsFormatBadge = false, minHeight = coverHeight)
            Column(Modifier.weight(1f).heightIn(min = coverHeight)) {
                item.seriesLine?.let { Text(it, style = Shiori.type.footnote, color = colors.label.copy(alpha = 0.85f), maxLines = 1, modifier = Modifier.padding(bottom = 2.dp)) }
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(item.shownTitle, style = Shiori.type.headline, color = colors.label, maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
                    if (item.isAwaited) Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(14.dp), tint = colors.label)
                }
                item.authors.firstOrNull()?.let { Text(it, style = Shiori.type.footnote, color = colors.secondaryLabel, maxLines = 1, modifier = Modifier.padding(top = 1.dp)) }
                val audio = item.format == BookFormat.AUDIOBOOK
                if (!coverTagsAreEmpty(item.language, audio)) Box(Modifier.padding(top = 3.dp)) { CoverTags(item.language, audio, isFrosted = false) }
                val release = (item as? ReleasedItem.Release)?.release
                val signed = item is ReleasedItem.Narrator || release?.source == ReleaseSource.AUTHOR || release?.source == ReleaseSource.NARRATOR
                if (signed) {
                    Spacer(Modifier.weight(1f).heightIn(min = 6.dp))
                    val name = when {
                        item is ReleasedItem.Narrator -> item.news.narrator
                        release?.source == ReleaseSource.NARRATOR -> release.narrator ?: ""
                        else -> release?.author?.name ?: release?.authors?.firstOrNull() ?: ""
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(7.dp), verticalAlignment = Alignment.CenterVertically) {
                        val portrait = release?.takeIf { it.source == ReleaseSource.AUTHOR }?.author?.portraitURL
                        if (portrait != null) {
                            CoverImage(portrait, Modifier.size(22.dp).clip(CircleShape), loading = { FriendMonogram(name, 22.dp) }, fallback = { FriendMonogram(name, 22.dp) })
                        } else {
                            FriendMonogram(name, 22.dp)
                        }
                        Text(name, style = Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold), color = colors.label, maxLines = 1)
                    }
                }
            }
        }
    }
}

/** "À venir": the next releases as cards, the list behind the title. */
@Composable
fun UpcomingRail(releases: List<UpcomingRelease>, onOpenList: () -> Unit, onOpen: (UpcomingRelease) -> Unit) {
    val state = rememberLazyListState()
    val inView by remember { derivedStateOf { state.firstVisibleItemIndex } }
    Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
        RowHeader(L("À venir"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE, action = onOpenList)
        if (releases.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                BoxWithConstraints {
                    val width = maxWidth - 40.dp
                    val cardWidth = if (releases.size > 1) width - 50.dp else width
                    LazyRow(state = state, contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        items(releases, key = { it.id }) { release ->
                            SeriesReleaseCard(
                                DiscoveredVolume(release.volume ?: 0, release.shownTitle, release.date, null, release.coverURL),
                                release.authors.firstOrNull() ?: "",
                                release.format == BookFormat.AUDIOBOOK,
                                onOpen = { onOpen(release) },
                                modifier = Modifier.width(cardWidth),
                                place = release.cardPlace,
                                language = release.language,
                                isAwaited = release.source == ReleaseSource.AWAITED,
                            )
                        }
                    }
                }
                if (releases.size > 1) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterHorizontally)) {
                        releases.indices.forEach { index ->
                            Box(Modifier.size(6.dp).background(if (index == inView) Shiori.colors.label else Shiori.colors.secondaryLabel.copy(alpha = 0.4f), CircleShape))
                        }
                    }
                }
            }
        }
    }
}

/** The friends' faces, ringed when they did something new; a tap narrows the feed to one. */
@Composable
fun FriendStoriesRail(stories: List<FriendStory>, selected: String?, onSelect: (String?) -> Unit, onInvite: () -> Unit) {
    val colors = Shiori.colors
    Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
        stories.forEach { story ->
            val isOn = selected == story.id
            Column(
                Modifier.width(68.dp).alpha(if (selected == null || isOn) 1f else 0.45f).plainClickable { onSelect(if (isOn) null else story.id) },
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                Box(
                    Modifier.border(if (isOn) 3.dp else 2.dp, if (story.isNew || isOn) colors.label else colors.label.copy(alpha = 0.2f), CircleShape).padding(3.dp),
                ) { AccountAvatarView(story.avatar, story.name, 58.dp) }
                Text(story.name, style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = colors.label, maxLines = 1)
            }
        }
        Column(Modifier.width(68.dp).plainClickable(onClick = onInvite), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Box(Modifier.size(64.dp), contentAlignment = Alignment.Center) {
                val dash = colors.secondaryLabel
                Canvas(Modifier.size(64.dp)) {
                    drawCircle(dash, size.minDimension / 2 - 1.dp.toPx(), style = Stroke(1.5.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))))
                }
                Icon(Symbol("plus"), null, Modifier.size(22.dp), tint = colors.secondaryLabel)
            }
            Text(L("Inviter"), style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = colors.secondaryLabel)
        }
    }
}

/** The calendar of releases: each month's days, the date beside its books. */
@Composable
fun ReleaseList(sections: List<ReleaseMonthSection>, onOpen: (UpcomingRelease) -> Unit) {
    val colors = Shiori.colors
    Column {
        sections.forEach { section ->
            Text(section.title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 14.dp, bottom = 6.dp))
            section.days.forEach { day ->
                ShioriDivider(Modifier.padding(start = 20.dp))
                Row(Modifier.padding(horizontal = 20.dp, vertical = 3.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Column(Modifier.width(40.dp).padding(top = 10.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                        when {
                            day.symbol != null -> Icon(Symbol(day.symbol), L("Suivi"), Modifier.size(20.dp), tint = colors.secondaryLabel)
                            else -> {
                                day.weekday?.let { Text(it.uppercase(), style = Shiori.type.caption2.copy(fontWeight = FontWeight.Bold), color = colors.secondaryLabel) }
                                Text(day.label, style = if (day.weekday == null) Shiori.type.footnote.copy(fontWeight = FontWeight.Bold) else Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = colors.label, maxLines = 2)
                            }
                        }
                    }
                    Column(Modifier.weight(1f)) { day.releases.forEach { UpcomingReleaseRow(it) { onOpen(it) } } }
                }
            }
        }
    }
}

@Composable
private fun UpcomingReleaseRow(release: UpcomingRelease, onOpen: () -> Unit) {
    val colors = Shiori.colors
    val title = release.title ?: if (release.format == BookFormat.BOOK) L("Nouveau roman") else L("Nouveau livre")
    val subtitle = if (release.title != null) release.reason else "${release.authors.firstOrNull() ?: ""} · ${L("sans titre")}"
    Row(Modifier.fillMaxWidth().plainClickable(onClick = onOpen).padding(vertical = 7.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (release.title == null) {
            Box(Modifier.size(30.dp, 45.dp).background(Brush.linearGradient(listOf(Color(0xFF4A4A4A), Color(0xFF2B2B2B))), RoundedCornerShape(3.dp)), contentAlignment = Alignment.Center) {
                Text("?", style = Shiori.type.caption.copy(fontWeight = FontWeight.SemiBold), color = Color.White)
            }
        } else {
            BookCover(release.cover, 30.dp, showsFormatBadge = false)
        }
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(1.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.label, maxLines = 2, modifier = Modifier.weight(1f, fill = false))
                if (release.source == ReleaseSource.AWAITED) Icon(Symbol("binoculars"), L("Suivi"), Modifier.size(12.dp), tint = colors.label)
            }
            Text(subtitle, style = Shiori.type.caption, color = colors.secondaryLabel, maxLines = 1)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun NewsRowsPreview() = PreviewSurface {
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        FeedEventRow(DebugFixtures.newsEvents[0], emptyList(), wished = false, awaited = false, onOpen = {}, onAdd = { _, _ -> }, onWish = {}, onAwait = {})
        UpcomingRail(DebugFixtures.upcoming, onOpenList = {}, onOpen = {})
        FriendStoriesRail(
            DebugFixtures.friends.map {
                com.polyforms.shiori.features.news.FriendStory(it.id, it.firstName ?: "", com.polyforms.shiori.shared.account.AccountAvatar.Initials, isNew = true)
            },
            selected = null,
            onSelect = {},
            onInvite = {},
        )
        ReleaseList(com.polyforms.shiori.features.news.ReleaseCalendar(DebugFixtures.upcoming).sections) {}
    }
}
