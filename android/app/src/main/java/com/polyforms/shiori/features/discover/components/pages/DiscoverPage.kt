package com.polyforms.shiori.features.discover.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.FollowedAuthor
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.features.discover.AuthorNews
import com.polyforms.shiori.features.discover.AuthorNewsItem
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.AwardSection
import com.polyforms.shiori.features.discover.AwardWinner
import com.polyforms.shiori.features.discover.DiscoverCategory
import com.polyforms.shiori.features.discover.DiscoverSummaryLine
import com.polyforms.shiori.features.discover.DiscoveriesLine
import com.polyforms.shiori.features.discover.DiscoveryFeed
import com.polyforms.shiori.features.discover.DiscoveryVolume
import com.polyforms.shiori.features.discover.ReleaseSection
import com.polyforms.shiori.features.discover.SagaDiscovery
import com.polyforms.shiori.features.discover.Suggestion
import com.polyforms.shiori.features.discover.components.organisms.AuthorReleasesSummary
import com.polyforms.shiori.features.discover.components.organisms.AuthorWorksStrip
import com.polyforms.shiori.features.discover.components.organisms.AwaitedEditionTile
import com.polyforms.shiori.features.discover.components.organisms.AwardWinnerTile
import com.polyforms.shiori.features.discover.components.organisms.CoverFocus
import com.polyforms.shiori.features.discover.components.organisms.DiscoverSummaryRow
import com.polyforms.shiori.features.discover.components.organisms.DiscoveriesSummaryRow
import com.polyforms.shiori.features.discover.components.organisms.FirstLookProgress
import com.polyforms.shiori.features.discover.components.organisms.LovedAuthorsStrip
import com.polyforms.shiori.features.discover.components.organisms.LovedBookTile
import com.polyforms.shiori.features.discover.components.organisms.LovedSagasStrip
import com.polyforms.shiori.features.discover.components.organisms.SagaReleasesSummary
import com.polyforms.shiori.features.discover.components.organisms.SeriesNewsStrip
import com.polyforms.shiori.features.discover.components.organisms.SummaryCoverWidth
import com.polyforms.shiori.features.discover.latestFirst
import com.polyforms.shiori.features.discover.recentAuthors
import com.polyforms.shiori.features.discover.recentSagas
import com.polyforms.shiori.features.discover.sagas
import com.polyforms.shiori.features.discover.seriesNews
import com.polyforms.shiori.features.discover.upcoming
import com.polyforms.shiori.features.discover.upcomingAuthors
import com.polyforms.shiori.features.friends.LovedAuthor
import com.polyforms.shiori.features.friends.LovedBook
import com.polyforms.shiori.features.friends.LovedSaga
import com.polyforms.shiori.shared.FollowedSeries
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.atoms.LanguageTag
import com.polyforms.shiori.shared.components.atoms.OpinionMark
import com.polyforms.shiori.shared.components.atoms.ReadingStatusBadge
import com.polyforms.shiori.shared.components.atoms.SagaName
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.LibraryShelf
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.color
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Everything Découvrir's page can ask for. */
sealed interface DiscoverAction {
    data class OpenSeries(val row: SagaDiscovery) : DiscoverAction
    data class OpenVolume(val volume: DiscoveryVolume) : DiscoverAction
    data class OpenAuthor(val key: String, val name: String, val isOffered: Boolean = false) : DiscoverAction
    data class OpenFriendBook(val loved: LovedBook) : DiscoverAction
    data class OpenFriendSaga(val loved: LovedSaga) : DiscoverAction
    data class OpenAwaited(val edition: AwaitedEdition) : DiscoverAction
    data class OpenWinner(val winner: AwardWinner) : DiscoverAction
    data class OpenSuggestion(val suggestion: Suggestion) : DiscoverAction
    data object Refresh : DiscoverAction
    data object Retry : DiscoverAction
}

/**
 * Découvrir: every saga the reader follows with the next volume announced, read and heard
 * together. Laid out as the Library: the capsule switches between "Livres" — one summary card,
 * a line per category over a strip of its covers, then "Nouveautés séries" — "Séries" and
 * "Auteurs", the friends' hearts above each.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DiscoverPage(
    shelf: LibraryShelf,
    feed: DiscoveryFeed,
    awaited: List<AwaitedEdition>,
    focusedAwaited: String?,
    awards: List<AwardSection>,
    discoveries: DiscoveriesLine?,
    isLookingUp: Boolean,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (DiscoverAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val act: (DiscoverAction) -> Unit = { scope.launch { onAction(it) } }
    var refreshing by remember { mutableStateOf(false) }
    when {
        isLookingUp -> FirstLookProgress()
        feed.sagas != null -> PullToRefreshBox(refreshing, onRefresh = {
            refreshing = true
            scope.launch {
                onAction(DiscoverAction.Refresh)
                refreshing = false
            }
        }, Modifier.fillMaxSize()) {
            val state = rememberLazyListState()
            LaunchedEffect(focusedAwaited) { if (focusedAwaited != null && shelf == LibraryShelf.BOOKS) state.animateScrollToItem(1) }
            LazyColumn(Modifier.fillMaxSize(), state, contentPadding = PaddingValues(bottom = 120.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                item(key = "title") { LargeTitle(L("Découvrir")) }
                if (shelf == LibraryShelf.BOOKS) summary(feed, awaited, focusedAwaited, awards, discoveries, act) else friendPicks(shelf, feed, act)
                val isEmpty = when (shelf) {
                    LibraryShelf.BOOKS -> feed.picks.books.isEmpty() && awaited.isEmpty() && awards.isEmpty()
                    LibraryShelf.SERIES -> feed.picks.sagas.isEmpty()
                    LibraryShelf.AUTHORS -> feed.picks.authors.isEmpty()
                }
                if (shelf == LibraryShelf.AUTHORS) authorSections(feed, isEmpty, act) else sagaSections(shelf, feed, isEmpty, act)
            }
        }
        errorMessage != null && !isLoading -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Découvrir indisponible"), errorMessage) { onAction(DiscoverAction.Retry) }
        }
        else -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
    }
}

/** The Books shelf at a glance: the editions awaited, the discoveries, the winners, the hearts. */
private fun LazyListScope.summary(
    feed: DiscoveryFeed,
    awaited: List<AwaitedEdition>,
    focusedAwaited: String?,
    awards: List<AwardSection>,
    discoveries: DiscoveriesLine?,
    act: (DiscoverAction) -> Unit,
) {
    val loved = feed.picks.books
    if (awaited.isEmpty() && discoveries == null && awards.isEmpty() && loved.isEmpty()) return
    item(key = "summary") {
        FormSection {
            var first = true
            @Composable
            fun divider() {
                if (!first) ShioriDivider()
                first = false
            }
            if (awaited.isNotEmpty()) {
                divider()
                val focus = focusedAwaited?.let { id -> awaited.indexOfFirst { it.id == id }.takeIf { it >= 0 }?.let { CoverFocus(id, it) } }
                DiscoverSummaryRow(DiscoverCategory.SOON.title, DiscoverSummaryLine.soon(awaited), symbol = DiscoverCategory.SOON.symbol, tint = DiscoverCategory.SOON.tint.color(), scrolledTo = focus) {
                    items(awaited, key = { it.id }) { edition -> AwaitedEditionTile(edition, SummaryCoverWidth) { act(DiscoverAction.OpenAwaited(edition)) } }
                }
            }
            if (discoveries != null) {
                divider()
                DiscoveriesSummaryRow(discoveries, SummaryCoverWidth) { act(DiscoverAction.OpenSuggestion(it)) }
            }
            if (awards.isNotEmpty()) {
                divider()
                DiscoverSummaryRow(DiscoverCategory.AWARDS.title, DiscoverSummaryLine.awards(awards), symbol = DiscoverCategory.AWARDS.symbol, tint = DiscoverCategory.AWARDS.tint.color()) {
                    items(awards.flatMap { it.winners }.latestFirst, key = { it.id }) { winner -> AwardWinnerTile(winner, SummaryCoverWidth) { act(DiscoverAction.OpenWinner(winner)) } }
                }
            }
            if (loved.isNotEmpty()) {
                divider()
                DiscoverSummaryRow(DiscoverCategory.FRIENDS.title, DiscoverSummaryLine.friends(loved), symbol = DiscoverCategory.FRIENDS.symbol, tint = DiscoverCategory.FRIENDS.tint.color()) {
                    items(loved, key = { it.id }) { picked -> LovedBookTile(picked, SummaryCoverWidth) { act(DiscoverAction.OpenFriendBook(picked)) } }
                }
            }
        }
    }
}

/** "Coups de cœur de vos amis", in the shape of the shelf on screen. */
private fun LazyListScope.friendPicks(shelf: LibraryShelf, feed: DiscoveryFeed, act: (DiscoverAction) -> Unit) {
    val picks = feed.picks
    when (shelf) {
        LibraryShelf.SERIES -> if (picks.sagas.isNotEmpty()) item(key = "picks") {
            FormSection(L("Coups de cœur de vos amis")) { LovedSagasStrip(picks.sagas) { act(DiscoverAction.OpenFriendSaga(it)) } }
        }
        LibraryShelf.AUTHORS -> if (picks.authors.isNotEmpty()) item(key = "picks") {
            FormSection(L("Coups de cœur de vos amis")) {
                LovedAuthorsStrip(picks.authors) { loved: LovedAuthor -> act(DiscoverAction.OpenAuthor(loved.key, loved.name, isOffered = true)) }
            }
        }
        LibraryShelf.BOOKS -> Unit
    }
}

private fun LazyListScope.empty(symbol: String, message: String) {
    item(key = "empty") {
        Box(Modifier.fillMaxWidth().padding(top = 48.dp), contentAlignment = Alignment.Center) { EmptyState(symbol, L("Rien de neuf pour l'instant"), message) }
    }
}

/** The sagas' volumes just out, then announced: one strip on Books, two lists on Series. */
private fun LazyListScope.sagaSections(shelf: LibraryShelf, feed: DiscoveryFeed, isEmpty: Boolean, act: (DiscoverAction) -> Unit) {
    val upcoming = feed.upcoming
    val recent = feed.recentSagas
    when {
        upcoming.isEmpty() && recent.isEmpty() -> if (isEmpty) empty("sparkles", L("Les nouveautés et les prochains tomes annoncés de vos séries apparaîtront ici."))
        shelf == LibraryShelf.BOOKS -> item(key = "series-news") {
            FormSection(L("Nouveautés séries")) { SeriesNewsStrip(feed.seriesNews) { act(DiscoverAction.OpenVolume(it)) } }
        }
        else -> {
            if (recent.isNotEmpty()) item(key = "recent") { SagaList(L("Nouvelles parutions"), recent, ReleaseSection.RECENT, act) }
            if (upcoming.isNotEmpty()) item(key = "upcoming") { SagaList(L("Prochaines sorties"), upcoming, ReleaseSection.UPCOMING, act) }
        }
    }
}

@Composable
private fun SagaList(title: String, rows: List<SagaDiscovery>, section: ReleaseSection, act: (DiscoverAction) -> Unit) {
    FormSection(title) {
        rows.forEachIndexed { index, row ->
            Column(Modifier.fillMaxWidth().plainClickable { act(DiscoverAction.OpenSeries(row)) }.padding(16.dp, 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                DiscoverSeriesRow(row.series)
                SagaReleasesSummary(row, section)
            }
            if (index < rows.lastIndex) ShioriDivider()
        }
    }
}

/** A saga as the Series tab lists it: the name and its marks, the author, the covers. */
@Composable
private fun DiscoverSeriesRow(entry: FollowedSeries) {
    val colors = Shiori.colors
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Box(Modifier.weight(1f)) { SagaName(entry.name, entry.isAudio, Shiori.type.body.copy(fontWeight = FontWeight.Medium)) }
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                    entry.language?.takeIf { it.isForeign }?.let { LanguageTag(it) }
                    entry.state?.let { Text(it.label, style = Shiori.type.caption, color = colors.secondaryLabel) }
                    OpinionMark(entry.opinion?.rating, entry.opinion?.favorite == true)
                }
            }
            entry.author?.let { Text(it, style = Shiori.type.subheadline, color = colors.secondaryLabel) }
        }
        LazyRow(contentPadding = PaddingValues(top = 6.dp, end = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            items(entry.volumes, key = { it.id }) { volume ->
                Box {
                    BookCover(volume, 44.dp, showsFormatBadge = false)
                    Box(Modifier.align(Alignment.TopEnd).offset(5.dp, (-5).dp)) { ReadingStatusBadge(volume.status) }
                }
            }
        }
    }
}

/** The authors with a book just out, then the ones with a book announced. */
private fun LazyListScope.authorSections(feed: DiscoveryFeed, isEmpty: Boolean, act: (DiscoverAction) -> Unit) {
    val upcoming = feed.upcomingAuthors
    val recent = feed.recentAuthors
    if (upcoming.isEmpty() && recent.isEmpty() && isEmpty) empty("person.2", L("Les nouveautés et les prochains livres annoncés de vos auteurs apparaîtront ici."))
    if (recent.isNotEmpty()) item(key = "authors-recent") { AuthorList(L("Nouvelles parutions"), recent, ReleaseSection.RECENT, act) }
    if (upcoming.isNotEmpty()) item(key = "authors-upcoming") { AuthorList(L("Prochaines sorties"), upcoming, ReleaseSection.UPCOMING, act) }
}

@Composable
private fun AuthorList(title: String, rows: List<AuthorNews>, section: ReleaseSection, act: (DiscoverAction) -> Unit) {
    val uri = LocalUriHandler.current
    FormSection(title) {
        rows.forEachIndexed { index, row ->
            val author = row.author
            val open = { act(DiscoverAction.OpenAuthor(author.key, author.name)) }
            val items = AuthorNewsItem.ordered(row.works(section), row.awaited(section), row.volumes(section), section)
            Column(Modifier.fillMaxWidth().padding(16.dp, 12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                AuthorHeading(author, Modifier.plainClickable(onClick = open))
                AuthorWorksStrip(items, author.name) { item ->
                    when (val source = item.source) {
                        is AuthorNewsItem.Source.Awaited -> act(DiscoverAction.OpenAwaited(source.edition))
                        is AuthorNewsItem.Source.Volume -> act(DiscoverAction.OpenVolume(source.volume))
                        is AuthorNewsItem.Source.Work -> source.work.audibleURL?.let { uri.openUri(it) } ?: open()
                    }
                }
                AuthorReleasesSummary(items, section)
            }
            if (index < rows.lastIndex) ShioriDivider()
        }
    }
}

/** The Authors shelf's heading: the portrait, the name, what the reader holds of them. */
@Composable
private fun AuthorHeading(author: FollowedAuthor, modifier: Modifier = Modifier) {
    Row(modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        AuthorAvatar(author.initials, author.portraitURL, size = 40.dp)
        Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(author.name, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = Shiori.colors.label)
            Text(if (author.bookCount == 1) L("1 livre") else L("%lld livres", author.bookCount), style = Shiori.type.subheadline, color = Shiori.colors.secondaryLabel)
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun DiscoverPagePreview() = PreviewSurface {
    DiscoverPage(
        com.polyforms.shiori.shared.components.molecules.LibraryShelf.BOOKS,
        DebugFixtures.discoverFeed,
        DebugFixtures.discoverAwaited,
        focusedAwaited = null,
        awards = emptyList(),
        discoveries = com.polyforms.shiori.features.discover.DiscoveriesLine.Shown(DebugFixtures.discoveries),
        isLookingUp = false,
        isLoading = false,
        errorMessage = null,
    ) {}
}
