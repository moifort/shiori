package com.polyforms.shiori.features.home.components.organisms

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeight
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.MonthlyDiscoveries
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryButtons
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoice
import com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices
import com.polyforms.shiori.features.home.HomePrompt
import com.polyforms.shiori.R
import com.polyforms.shiori.shared.components.molecules.ActionToggle
import com.polyforms.shiori.shared.components.styles.ActionButton
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.ActionSize
import com.polyforms.shiori.shared.components.styles.IconGesture
import com.polyforms.shiori.shared.components.styles.saturation
import androidx.annotation.DrawableRes
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.ui.res.painterResource
import com.polyforms.shiori.features.home.HomeRelease
import com.polyforms.shiori.features.home.releaseTile
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.components.atoms.CoverTags
import com.polyforms.shiori.shared.components.atoms.HeroProminentButton
import com.polyforms.shiori.shared.components.atoms.OutlinedTag
import com.polyforms.shiori.shared.components.atoms.coverTagsAreEmpty
import com.polyforms.shiori.shared.components.molecules.ReleaseDateBadge
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import java.time.LocalDate
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.Locale
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/**
 * One page of the Home hero: a release, a discovery, the page that asks for a rating, or, last,
 * one thing the reader has not set up yet: Audible, Kindle or a first friend.
 */
sealed interface HomeHeroItem {
    val id: String

    data class Release(val release: HomeRelease) : HomeHeroItem {
        override val id: String get() = "release-${release.id}"
    }

    data class Discovery(val suggestion: Suggestion) : HomeHeroItem {
        override val id: String get() = "discovery-${suggestion.id}"
    }

    data class NeedsRatings(val month: String) : HomeHeroItem {
        override val id: String get() = "needs-ratings-$month"
    }

    /** Something to set up, after every other page. */
    data class Prompt(val prompt: HomePrompt) : HomeHeroItem {
        override val id: String get() = "prompt-${prompt.name.lowercase()}"
    }

    companion object {
        const val RELEASE_WINDOW = 6
        const val RECENT_WINDOW = 6

        /**
         * Releases of the week around today first, then the month's discoveries. A month with no
         * selection for want of a rated book closes on its page; one whose discoveries ran out
         * has none. The prompt comes last.
         */
        fun items(
            releases: List<HomeRelease>,
            discoveries: List<Suggestion>,
            needsRatingsMonth: String? = null,
            seen: Set<String> = emptySet(),
            prompt: HomePrompt? = null,
            today: LocalDate = LocalDate.now(),
        ): List<HomeHeroItem> {
            val month = "%04d-%02d".format(today.year, today.monthValue)
            val out = mutableListOf<Pair<HomeRelease, Long>>()
            val thisMonth = mutableListOf<HomeRelease>()
            val coming = mutableListOf<Pair<HomeRelease, Long>>()
            for (release in releases) {
                if (release.id in seen) continue
                val date = release.date ?: continue
                if (date.length == 7) {
                    if (date == month) thisMonth += release
                    continue
                }
                val days = daysFromToday(date, today) ?: continue
                if (days > 0) {
                    if (days <= RELEASE_WINDOW) coming += release to days
                } else if (-days <= RECENT_WINDOW || date.startsWith(month)) {
                    out += release to days
                }
            }
            val collator = java.text.Collator.getInstance()
            val lined = out.sortedWith { a, b -> if (a.second != b.second) b.second.compareTo(a.second) else collator.compare(a.first.name, b.first.name) }.map { it.first } +
                thisMonth.sortedWith { a, b -> collator.compare(a.name, b.name) } +
                coming.sortedWith { a, b -> if (a.second != b.second) a.second.compareTo(b.second) else collator.compare(a.first.name, b.first.name) }.map { it.first }
            val done = if (discoveries.isEmpty()) {
                needsRatingsMonth?.let { listOf(NeedsRatings(it)) } ?: emptyList()
            } else {
                emptyList()
            }
            return lined.map(::Release) + discoveries.map(::Discovery) + done + listOfNotNull(prompt?.let(::Prompt))
        }

        fun releaseBadge(date: String, today: LocalDate = LocalDate.now()): String {
            val month = "%04d-%02d".format(today.year, today.monthValue)
            val days = if (date.length == 10) daysFromToday(date, today) else null
            if (days == null) return if (date == month) L("Sortie ce mois-ci") else L("Bientôt")
            return when {
                days == 0L -> L("Sortie aujourd'hui")
                days == -1L -> L("Sortie hier")
                days == -2L -> L("Sortie avant-hier")
                days in -RECENT_WINDOW.toLong()..-3L -> L("Sortie cette semaine")
                days < 0 -> L("Sortie ce mois-ci")
                days == 1L -> L("Sort demain")
                else -> {
                    val day = today.plusDays(days)
                    val weekday = day.dayOfWeek.getDisplayName(TextStyle.FULL, Locale.getDefault())
                    val week = WeekFields.of(Locale.getDefault())
                    val sameWeek = day.get(week.weekOfWeekBasedYear()) == today.get(week.weekOfWeekBasedYear()) && day.year == today.year
                    if (sameWeek) L("Sort %@", weekday) else L("Sort %@ prochain", weekday)
                }
            }
        }

        fun daysFromToday(date: String, today: LocalDate = LocalDate.now()): Long? {
            val parts = date.split("-").mapNotNull { it.toIntOrNull() }
            if (parts.size != 3) return null
            val day = runCatching { LocalDate.of(parts[0], parts[1], parts[2]) }.getOrNull() ?: return null
            return ChronoUnit.DAYS.between(today, day)
        }
    }
}

/** A discovery as the hero draws its cover. */
val Suggestion.tile: Book
    get() = Book(
        id = "suggestion-$id",
        title = title,
        authors = authors,
        format = if (format == com.polyforms.shiori.features.discover.ReleaseFormat.AUDIOBOOK) BookFormat.AUDIOBOOK else BookFormat.BOOK,
        coverURL = coverURL,
        status = ReadingStatus.TO_READ,
    )

private val coverWidth = 124.dp
private val coverHeight = coverWidth * 1.5f
private val topPadding = 26.dp
private val buttonsGap = 22.dp
private val buttonsHeight = 52.dp
private val dotsGap = 22.dp
private val dotsHeight = 7.dp
private val bottomPadding = 2.dp

/** How far the hero's wash rises above it, under the figures and the bar. */
val BACKDROP_RISE = 400.dp

/**
 * The Home hero on a phone: a page per release of the week and per discovery of the month,
 * swiped through, each over its own cover's wash.
 */
@Composable
fun HomeHeroCarousel(
    items: List<HomeHeroItem>,
    onOpenRelease: (HomeRelease) -> Unit,
    onOpen: (Suggestion) -> Unit,
    onChoice: suspend (Suggestion, DiscoveryChoice) -> Boolean,
    choices: DiscoveryChoices,
    onSeeRelease: (HomeRelease) -> Unit,
    onUnseeRelease: (HomeRelease) -> Unit,
    onRate: () -> Unit,
    /** A prompt's button: the connection or the invitation it asks for. */
    onPrompt: (HomePrompt) -> Unit = {},
    /** A prompt turned down from its closed eye. */
    onDismissPrompt: (HomePrompt) -> Unit = {},
    /** The eye pressed again: the prompt is asked again. */
    onUndismissPrompt: (HomePrompt) -> Unit = {},
    backdropCover: String?,
    discoveryMonth: String,
) {
    val pager = rememberPagerState { items.size }
    val topHeights = remember { mutableStateMapOf<String, Dp>() }
    val seen = remember { mutableStateMapOf<String, Boolean>() }
    val dismissedPrompts = remember { mutableStateMapOf<HomePrompt, Boolean>() }
    val density = LocalDensity.current
    val shownId = items.getOrNull(pager.currentPage)?.id
    val top = maxOf(coverHeight, shownId?.let { topHeights[it] } ?: 0.dp)
    val height by animateDpAsState(topPadding + top + buttonsGap + buttonsHeight + dotsGap + dotsHeight + bottomPadding, label = "hero")

    fun backdrop(item: HomeHeroItem?): String? = when (item) {
        is HomeHeroItem.Release -> releaseTile(item.release).coverURL
        is HomeHeroItem.Discovery -> item.suggestion.tile.coverURL
        else -> backdropCover
    }
    val shown = items.getOrNull(pager.currentPage)
    // A discovery turned down from the eye: black and white, cover and wash, as on its page.
    val turnedDown = shown is HomeHeroItem.Discovery && choices.isTurnedDown(shown.suggestion)
    val saturation by animateFloatAsState(if (turnedDown) 0f else 1f, tween(600), label = "turnedDown")
    Box(Modifier.fillMaxWidth().height(height)) {
        Crossfade(backdrop(shown), Modifier.saturation(saturation), label = "backdrop") { url ->
            CoverBackdrop(url, Modifier.fillMaxWidth().requiredHeight(height + BACKDROP_RISE).offset(y = -BACKDROP_RISE / 2), fadeHeight = 240.dp)
        }
        HorizontalPager(pager, Modifier.fillMaxSize(), key = { items[it].id }) { index ->
            val item = items[index]
            Box(Modifier.fillMaxSize()) {
                Column(
                    Modifier.fillMaxSize().padding(start = 20.dp, end = 20.dp, top = topPadding, bottom = dotsGap + dotsHeight + bottomPadding),
                ) {
                    Box(Modifier.onSizeChanged { topHeights[item.id] = with(density) { it.height.toDp() } }) {
                        when (item) {
                            is HomeHeroItem.Release -> ReleaseTop(item.release)
                            is HomeHeroItem.Discovery -> DiscoveryTop(
                                item.suggestion,
                                discoveryMonth,
                                isTurnedDown = choices.isTurnedDown(item.suggestion),
                            )
                            is HomeHeroItem.NeedsRatings -> ClosingTop(
                                StackMark.Symbol("star.fill"),
                                MonthlyDiscoveries.title(item.month),
                                L("Notez vos lectures"),
                                L("Donnez des étoiles ou un cœur à vos lectures pour recevoir vos livres du mois"),
                            )
                            is HomeHeroItem.Prompt -> ClosingTop(item.prompt.mark, item.prompt.badge, item.prompt.title, item.prompt.pitch)
                        }
                    }
                    Spacer(Modifier.weight(1f))
                    Row(Modifier.fillMaxWidth().height(buttonsHeight), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                        when (item) {
                            is HomeHeroItem.Release -> {
                                HeroButton(L("Voir la sortie"), "calendar", Modifier.weight(1f)) { onOpenRelease(item.release) }
                                // Seen, the eye on white; not seen, the eye slashed on glass. Pressed
                                // again, the release comes back. It leaves the line once the reader
                                // leaves the page, as a discovery turned down does.
                                ActionToggle(
                                    isOn = seen[item.release.id] == true,
                                    symbol = "eye",
                                    turnOnLabel = L("Marquer comme vu"),
                                    turnOffLabel = L("Marquer comme non vu"),
                                    gesture = IconGesture.BLINK,
                                ) { isSeen ->
                                    if (isSeen) {
                                        seen[item.release.id] = true
                                        onSeeRelease(item.release)
                                    } else {
                                        seen.remove(item.release.id)
                                        onUnseeRelease(item.release)
                                    }
                                }
                            }
                            is HomeHeroItem.Discovery -> {
                                HeroButton(L("Découvrir"), "sparkles", Modifier.weight(1f)) { onOpen(item.suggestion) }
                                DiscoveryButtons(item.suggestion, choices, onChoice)
                            }
                            is HomeHeroItem.NeedsRatings ->
                                HeroButton(L("Noter mes lectures"), "star.fill", Modifier.weight(1f), onClick = onRate)
                            is HomeHeroItem.Prompt -> {
                                HeroButton(item.prompt.action, null, Modifier.weight(1f)) { onPrompt(item.prompt) }
                                // Turned down, the eye fills white; pressed again, the prompt comes
                                // back. It leaves the line once the reader leaves the page.
                                ActionToggle(
                                    isOn = dismissedPrompts[item.prompt] == true,
                                    symbol = "eye.slash",
                                    offSymbol = "eye",
                                    turnOnLabel = L("Pas intéressé"),
                                    turnOffLabel = L("Plus intéressé"),
                                    gesture = IconGesture.BLINK,
                                ) { dismissed ->
                                    if (dismissed) {
                                        dismissedPrompts[item.prompt] = true
                                        onDismissPrompt(item.prompt)
                                    } else {
                                        dismissedPrompts.remove(item.prompt)
                                        onUndismissPrompt(item.prompt)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        if (items.size > 1) {
            Row(Modifier.align(Alignment.BottomCenter).padding(bottom = bottomPadding), horizontalArrangement = Arrangement.spacedBy(7.dp)) {
                items.indices.forEach { page ->
                    val on = page == pager.currentPage
                    val width by animateDpAsState(if (on) 22.dp else 7.dp, label = "dot")
                    Box(Modifier.size(width, dotsHeight).background(Color.White.copy(alpha = if (on) 0.95f else 0.4f), CircleShape))
                }
            }
        }
    }

}

/** A hero page's first action: white, 50 high, as wide as the room beside the round buttons. */
@Composable
private fun HeroButton(title: String, symbol: String?, modifier: Modifier = Modifier, onClick: () -> Unit) {
    ActionButton(onClick, modifier, size = ActionSize.LARGE, spansWidth = true) { ActionLabel(title, symbol, ActionSize.LARGE.side) }
}

@Composable
private fun Badge(text: String) {
    Text(
        text,
        style = Shiori.type.footnote.copy(fontWeight = FontWeight.SemiBold),
        color = Color.White,
        modifier = Modifier.background(Color.White.copy(alpha = 0.16f), CircleShape).border(0.5.dp, Color.White.copy(alpha = 0.28f), CircleShape)
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
private fun ReleaseTop(release: HomeRelease) {
    val tile = releaseTile(release)
    val date = release.date
    val countdown = date?.takeIf { it.length == 10 && (HomeHeroItem.daysFromToday(it) ?: 0) > 0 }?.let { ReleaseDateText.countdown(it) }
    val meta = listOfNotNull(tile.authorLine, tile.series?.volume?.let { L("Tome %lld", it) }).filter { it.isNotEmpty() }.joinToString(" · ")
    val leafDate = date?.takeIf { it.length == 10 && ReleaseDateText.isUpcoming(it) }
    Box {
        PageTop(tile, date?.let { HomeHeroItem.releaseBadge(it) } ?: L("Bientôt"), tile.title, meta, tile.series?.name, countdown, leafDate != null)
        if (leafDate != null) Box(Modifier.align(Alignment.TopEnd)) { ReleaseDateBadge(leafDate, onGlass = true) }
    }
}

@Composable
private fun DiscoveryTop(suggestion: Suggestion, month: String, isTurnedDown: Boolean) {
    PageTop(suggestion.tile, MonthlyDiscoveries.badge(month), suggestion.title, suggestion.authors.joinToString(", "), suggestion.reason, null, false, isTurnedDown)
}

@Composable
private fun PageTop(cover: Book, badge: String, title: String, meta: String, reason: String?, countdown: String?, leavesRoom: Boolean, isTurnedDown: Boolean = false) {
    // Turned down from the eye: black and white, as on its page.
    val saturation by animateFloatAsState(if (isTurnedDown) 0f else 1f, tween(600), label = "coverTurnedDown")
    Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.Top) {
        BookCover(cover, coverWidth, Modifier.shadow(18.dp, RoundedCornerShape(3.dp)).saturation(saturation), showsFormatBadge = false, isBound = true)
        Column(Modifier.weight(1f).padding(end = if (leavesRoom) 58.dp else 0.dp)) {
            Badge(badge)
            Text(title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Color.White, maxLines = 3, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 10.dp))
            if (meta.isNotEmpty()) {
                Text(meta, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.85f), maxLines = 2, overflow = TextOverflow.Ellipsis, modifier = Modifier.padding(top = 5.dp))
            }
            if (!reason.isNullOrEmpty()) {
                Text(reason, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.7f), modifier = Modifier.padding(top = 8.dp))
            }
            val isAudio = cover.format == BookFormat.AUDIOBOOK
            if (!coverTagsAreEmpty(cover.language, isAudio) || countdown != null) {
                Row(Modifier.padding(top = 10.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    CoverTags(cover, isFrosted = false)
                    if (countdown != null) OutlinedTag(countdown, isFrosted = false)
                }
            }
        }
    }
}

@Composable
private fun ClosingTop(mark: StackMark, badge: String, title: String, line: String) {
    Row(horizontalArrangement = Arrangement.spacedBy(18.dp), verticalAlignment = Alignment.Top) {
        DoneStack(mark, Modifier.size(coverWidth, coverHeight))
        Column(Modifier.weight(1f)) {
            Badge(badge)
            Text(title, style = Shiori.type.title2.copy(fontWeight = FontWeight.Bold), color = Color.White, modifier = Modifier.padding(top = 10.dp))
            Text(line, style = Shiori.type.subheadline, color = Color.White.copy(alpha = 0.75f), modifier = Modifier.padding(top = 8.dp))
        }
    }
}

/** What the front cover of a `DoneStack` carries: a symbol, or a service's logo. */
sealed interface StackMark {
    data class Symbol(val name: String) : StackMark
    data class Logo(@DrawableRes val drawable: Int) : StackMark
}

/** Three blank covers fanned out, a symbol on the front one. */
@Composable
fun DoneStack(symbol: String, modifier: Modifier = Modifier, scale: Float = 0.84f, coverSize: Pair<Dp, Dp> = 130.dp to 192.dp) =
    DoneStack(StackMark.Symbol(symbol), modifier, scale, coverSize)

/** Three blank covers fanned out, a symbol or a logo on the front one. */
@Composable
fun DoneStack(mark: StackMark, modifier: Modifier = Modifier, scale: Float = 0.84f, coverSize: Pair<Dp, Dp> = 130.dp to 192.dp) {
    val shape = RoundedCornerShape(10.dp)
    @Composable
    fun Blank(modifier: Modifier) {
        Box(
            modifier.size(coverSize.first * scale, coverSize.second * scale)
                .background(Brush.linearGradient(listOf(Color.White.copy(alpha = 0.2f), Color.White.copy(alpha = 0.06f))), shape)
                .border(1.dp, Color.White.copy(alpha = 0.24f), shape),
        )
    }
    Box(modifier, contentAlignment = Alignment.Center) {
        Blank(Modifier.offset(x = (-14).dp * scale, y = 4.dp * scale).rotate(-7f))
        Blank(Modifier.offset(x = 14.dp * scale, y = 6.dp * scale).rotate(6f))
        Box(contentAlignment = Alignment.Center) {
            Blank(Modifier.shadow(18.dp, shape))
            when (mark) {
                is StackMark.Symbol -> Icon(Symbol(mark.name), null, Modifier.size(40.dp * scale), tint = Color.White.copy(alpha = 0.92f))
                is StackMark.Logo -> Icon(painterResource(mark.drawable), null, Modifier.size(60.dp * scale), tint = Color.White.copy(alpha = 0.92f))
            }
        }
    }
}

private val HomePrompt.mark: StackMark
    get() = when (this) {
        HomePrompt.AUDIBLE -> StackMark.Logo(R.drawable.logo_audible)
        HomePrompt.KINDLE -> StackMark.Logo(R.drawable.logo_kindle)
        HomePrompt.FRIENDS -> StackMark.Symbol("person.badge.plus")
    }

private val HomePrompt.badge: String
    get() = when (this) {
        HomePrompt.AUDIBLE -> "Audible"
        HomePrompt.KINDLE -> "Kindle"
        HomePrompt.FRIENDS -> L("Amis")
    }

private val HomePrompt.title: String
    get() = when (this) {
        HomePrompt.AUDIBLE -> L("Vos livres audio, ici")
        HomePrompt.KINDLE -> L("Votre Kindle, rangé")
        HomePrompt.FRIENDS -> L("Lisez avec vos amis")
    }

private val HomePrompt.pitch: String
    get() = when (this) {
        HomePrompt.AUDIBLE -> L("Connectez Audible : vos écoutes rejoignent la bibliothèque avec leur série et l'avancement, sans rien scanner.")
        HomePrompt.KINDLE -> L("Connectez Kindle : vos ebooks arrivent avec couverture et série, et ceux que vous avez finis sont marqués lus.")
        HomePrompt.FRIENDS -> L("Invitez un ami : voyez ce qu'il lit et ses coups de cœur, et piochez dans sa bibliothèque.")
    }

private val HomePrompt.action: String
    get() = when (this) {
        HomePrompt.AUDIBLE -> L("Connecter Audible")
        HomePrompt.KINDLE -> L("Connecter Kindle")
        HomePrompt.FRIENDS -> L("Inviter")
    }

@Preview(showBackground = true)
@Composable
private fun HomeHeroCarouselPromptsPreview() = PreviewSurface {
    HomeHeroCarousel(
        items = HomePrompt.entries.map(HomeHeroItem::Prompt),
        onOpenRelease = {},
        onOpen = {},
        onChoice = { _, _ -> true },
        choices = androidx.compose.runtime.remember { com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices() },
        onSeeRelease = {},
        onUnseeRelease = {},
        onRate = {},
        backdropCover = null,
        discoveryMonth = DebugFixtures.discoveries.month,
    )
}

@Preview(showBackground = true)
@Composable
private fun HomeHeroCarouselPreview() = PreviewSurface {
    HomeHeroCarousel(
        items = listOf(
            HomeHeroItem.Release(com.polyforms.shiori.features.home.HomeRelease.Volume(com.polyforms.shiori.features.discover.DiscoveryVolume(DebugFixtures.sagas[0], DebugFixtures.announcedVolume))),
            HomeHeroItem.Discovery(DebugFixtures.discoveries.suggestions[0]),
        ),
        onOpenRelease = {},
        onOpen = {},
        onChoice = { _, _ -> true },
        choices = androidx.compose.runtime.remember { com.polyforms.shiori.features.discover.components.organisms.DiscoveryChoices() },
        onSeeRelease = {},
        onUnseeRelease = {},
        onRate = {},
        backdropCover = null,
        discoveryMonth = DebugFixtures.discoveries.month,
    )
}
