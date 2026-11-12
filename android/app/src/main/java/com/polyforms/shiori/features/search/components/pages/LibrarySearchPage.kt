package com.polyforms.shiori.features.search.components.pages

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.search.LibrarySearchMatcher
import com.polyforms.shiori.features.search.SearchFilter
import com.polyforms.shiori.features.search.SearchResults
import com.polyforms.shiori.features.search.SearchText
import com.polyforms.shiori.features.search.SeriesHit
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.EmptyStateAction
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.organisms.BookRow
import com.polyforms.shiori.shared.components.organisms.CoverTile
import com.polyforms.shiori.shared.components.styles.RoundedTextField
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

sealed interface SearchAction {
    data class OpenBook(val book: Book) : SearchAction
    data class OpenSeries(val hit: SeriesHit) : SearchAction
    data object ToggleFavorites : SearchAction
    data class Select(val status: ReadingStatus) : SearchAction
    data object ClearFilter : SearchAction
    data class UseRecent(val recent: String) : SearchAction
    data object ClearRecentSearches : SearchAction
    data object Retry : SearchAction
}

/** The search: the field, filter chips, then the recents or what matches. */
@Composable
fun LibrarySearchPage(
    query: String,
    onQuery: (String) -> Unit,
    filter: SearchFilter,
    results: SearchResults,
    recentSearches: List<String>,
    recentlyViewed: List<Book>,
    covers: Map<String, String>,
    isPreparing: Boolean,
    failed: Boolean,
    isSearching: Boolean,
    onAction: suspend (SearchAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    val colors = Shiori.colors
    fun send(action: SearchAction) {
        scope.launch { onAction(action) }
    }
    fun withCover(book: Book): Book = if (book.coverURL == null) covers[book.id]?.let { book.copy(coverURL = it) } ?: book else book
    val typed = SearchText.normalized(query).isNotEmpty()
    val showsNoResult = !isPreparing && isSearching && results.series.isEmpty() && results.books.isEmpty()

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Text(L("Rechercher"), style = Shiori.type.largeTitle, color = colors.label, modifier = Modifier.padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 8.dp))
        RoundedTextField(query, onQuery, L("Titre, auteur, série"), Modifier.padding(horizontal = 16.dp), leadingSymbol = "magnifyingglass")
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Chip(L("Favoris"), "heart.fill", filter.favorites) { send(SearchAction.ToggleFavorites) }
            SearchFilter.statuses.forEach { status ->
                val title = when (status) {
                    ReadingStatus.READING -> L("En cours")
                    ReadingStatus.TO_READ -> L("À lire")
                    else -> L("Lus")
                }
                Chip(title, status.symbol, filter.status == status) { send(SearchAction.Select(status)) }
            }
        }
        Box(Modifier.fillMaxSize()) {
            when {
                failed -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    FailureState(L("Recherche indisponible"), L("Vos livres n’ont pas pu être chargés.")) { onAction(SearchAction.Retry) }
                }
                isPreparing -> Column(Modifier.fillMaxWidth().padding(vertical = 48.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    CircularProgressIndicator()
                    Text(L("Préparation de vos livres…"), style = Shiori.type.subheadline, color = colors.secondaryLabel)
                }
                showsNoResult -> Box(Modifier.fillMaxSize().padding(bottom = 120.dp), contentAlignment = Alignment.Center) {
                    if (results.hiddenByFilter > 0) {
                        EmptyState(
                            "line.3.horizontal.decrease.circle",
                            L("Aucun livre ne correspond"),
                            L("Hors de ce filtre, %lld livres correspondent.", results.hiddenByFilter),
                            primary = EmptyStateAction(L("Retirer le filtre"), "xmark.circle") { onAction(SearchAction.ClearFilter) },
                        )
                    } else {
                        EmptyState("magnifyingglass", L("Aucun livre ne correspond"), L("Cherchez un titre, un auteur ou une série de votre bibliothèque."))
                    }
                }
                else -> LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 120.dp)) {
                    if (!typed && !filter.isActive && recentlyViewed.isNotEmpty()) {
                        item(key = "viewed") {
                            Section(L("Vus récemment")) {
                                Row(Modifier.horizontalScroll(rememberScrollState()).padding(16.dp), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                                    recentlyViewed.forEach { book ->
                                        CoverTile(withCover(book), book.title, Modifier.plainClickable { send(SearchAction.OpenBook(book)) }, width = 72.dp)
                                    }
                                }
                            }
                        }
                    }
                    if (!typed && recentSearches.isNotEmpty()) {
                        item(key = "recents") {
                            Section(L("Recherches récentes"), trailing = L("Effacer") to { send(SearchAction.ClearRecentSearches) }) {
                                recentSearches.forEachIndexed { index, recent ->
                                    Row(
                                        Modifier.fillMaxWidth().plainClickable { send(SearchAction.UseRecent(recent)) }.padding(horizontal = 16.dp, vertical = 13.dp),
                                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                                        verticalAlignment = Alignment.CenterVertically,
                                    ) {
                                        Icon(Symbol("clock.arrow.circlepath"), null, Modifier.size(18.dp), tint = colors.accent)
                                        Text(recent, style = Shiori.type.body, color = colors.label)
                                    }
                                    if (index < recentSearches.lastIndex) ShioriDivider(Modifier.padding(start = 46.dp))
                                }
                            }
                        }
                    }
                    if (!typed && !filter.isActive && recentlyViewed.isEmpty() && recentSearches.isEmpty()) {
                        item(key = "help") {
                            Column(Modifier.fillMaxWidth().padding(vertical = 24.dp, horizontal = 32.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                Icon(Symbol("binoculars"), null, Modifier.size(40.dp), tint = colors.secondaryLabel)
                                Text(L("Cherchez un titre, un auteur ou une série de votre bibliothèque."), style = Shiori.type.subheadline, color = colors.secondaryLabel, textAlign = TextAlign.Center)
                            }
                        }
                    }
                    if (isSearching && results.series.isNotEmpty()) {
                        item(key = "series") {
                            Section(L("Séries")) {
                                results.series.forEachIndexed { index, hit ->
                                    SeriesHitRow(hit, hit.books.firstOrNull()?.let(::withCover)) { send(SearchAction.OpenSeries(hit)) }
                                    if (index < results.series.lastIndex) ShioriDivider(Modifier.padding(start = 68.dp))
                                }
                            }
                        }
                    }
                    if (isSearching && results.books.isNotEmpty()) {
                        item(key = "books-header") { Header(L("Livres · %lld", results.books.size)) }
                        items(results.books, key = { it.id }) { book ->
                            val index = results.books.indexOf(book)
                            val shape = when {
                                results.books.size == 1 -> RoundedCornerShape(12.dp)
                                index == 0 -> RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp)
                                index == results.books.lastIndex -> RoundedCornerShape(bottomStart = 12.dp, bottomEnd = 12.dp)
                                else -> RoundedCornerShape(0.dp)
                            }
                            Column(Modifier.padding(horizontal = 16.dp).clip(shape).background(colors.secondaryGroupedBackground)) {
                                Box(Modifier.plainClickable { send(SearchAction.OpenBook(book)) }.padding(horizontal = 16.dp, vertical = 10.dp)) {
                                    BookRow(
                                        book.title,
                                        book.authorLine,
                                        withCover(book),
                                        book.status,
                                        book.shownRating,
                                        highlightedTitle = highlighted(book.title, query),
                                        ratingIsInherited = book.ratingIsInherited,
                                        series = book.series,
                                        statusTag = book.status,
                                        genre = book.genre,
                                        subgenre = book.subgenres.firstOrNull(),
                                        language = book.language,
                                        isFavorite = book.favorite,
                                        isHidden = book.hidden,
                                        listeningProgress = book.unfinishedListeningProgress?.let { "$it%" },
                                    )
                                }
                                if (index < results.books.lastIndex) ShioriDivider(Modifier.padding(start = 76.dp))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun Header(title: String, trailing: Pair<String, () -> Unit>? = null) {
    Row(Modifier.fillMaxWidth().padding(start = 32.dp, end = 32.dp, top = 18.dp, bottom = 6.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(title.uppercase(), style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel, modifier = Modifier.weight(1f))
        trailing?.let { (label, action) -> Text(label, style = Shiori.type.subheadline, color = Shiori.colors.accent, modifier = Modifier.plainClickable(onClick = action)) }
    }
}

@Composable
private fun Section(title: String, trailing: Pair<String, () -> Unit>? = null, content: @Composable () -> Unit) {
    Column {
        Header(title, trailing)
        Column(Modifier.padding(horizontal = 16.dp).clip(RoundedCornerShape(12.dp)).background(Shiori.colors.secondaryGroupedBackground)) { content() }
    }
}

@Composable
private fun Chip(title: String, symbol: String, isOn: Boolean, onClick: () -> Unit) {
    val colors = Shiori.colors
    Row(
        Modifier.clip(CircleShape).background(if (isOn) colors.accent else colors.fill).plainClickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(Symbol(symbol), null, Modifier.size(15.dp), tint = if (isOn) androidx.compose.ui.graphics.Color.White else colors.label)
        Text(title, style = Shiori.type.subheadline, color = if (isOn) androidx.compose.ui.graphics.Color.White else colors.label)
    }
}

@Composable
private fun SeriesHitRow(hit: SeriesHit, cover: Book?, onClick: () -> Unit) {
    val colors = Shiori.colors
    Row(Modifier.fillMaxWidth().plainClickable(onClick = onClick).padding(horizontal = 16.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
        if (cover != null) BookCover(cover, 40.dp, showsFormatBadge = false)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            Text(hit.name, style = Shiori.type.body.copy(fontWeight = FontWeight.Medium), color = colors.label, maxLines = 2)
            Text(hit.authors.joinToString(", "), style = Shiori.type.subheadline, color = colors.secondaryLabel, maxLines = 1)
            Text(L("%lld tomes", hit.books.size), style = Shiori.type.caption, color = colors.secondaryLabel)
        }
        Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
    }
}

/** The title with the words the query matches washed in yellow. */
private fun highlighted(title: String, query: String): AnnotatedString? {
    if (SearchText.normalized(query).isEmpty()) return null
    var found = false
    val marked = buildAnnotatedString {
        var last = 0
        Regex("\\S+").findAll(title).forEach { match ->
            append(title.substring(last, match.range.first))
            if (LibrarySearchMatcher.highlights(match.value, query)) {
                found = true
                withStyle(SpanStyle(background = androidx.compose.ui.graphics.Color.Yellow.copy(alpha = 0.35f))) { append(match.value) }
            } else {
                append(match.value)
            }
            last = match.range.last + 1
        }
        append(title.substring(last))
    }
    return if (found) marked else null
}

@Preview(showBackground = true)
@Composable
private fun LibrarySearchPagePreview() = PreviewSurface {
    LibrarySearchPage(
        query = "fon",
        onQuery = {},
        filter = com.polyforms.shiori.features.search.SearchFilter(),
        results = com.polyforms.shiori.features.search.SearchResults(books = listOf(DebugFixtures.toRead[3])),
        recentSearches = listOf("Dune"),
        recentlyViewed = DebugFixtures.reading,
        covers = emptyMap(),
        isPreparing = false,
        failed = false,
        isSearching = false,
    ) {}
}
