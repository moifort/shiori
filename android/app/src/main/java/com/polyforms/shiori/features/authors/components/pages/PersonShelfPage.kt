package com.polyforms.shiori.features.authors.components.pages

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
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
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.authors.AuthorListOrder
import com.polyforms.shiori.features.authors.ShelvedPerson
import com.polyforms.shiori.features.authors.components.organisms.AuthorAvatar
import com.polyforms.shiori.features.authors.pillLabel
import com.polyforms.shiori.features.home.components.organisms.PosterRow
import com.polyforms.shiori.features.home.components.organisms.PosterRowItem
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.molecules.FilterPill
import com.polyforms.shiori.shared.components.molecules.FilterPills
import com.polyforms.shiori.shared.components.molecules.LoadMoreRow
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.LargeTitle
import kotlinx.coroutines.launch
import androidx.compose.ui.tooling.preview.Preview
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** What a person shelf asks of its screen. */
sealed interface PersonShelfAction<out Person> {
    data class OpenPerson<Person>(val person: Person) : PersonShelfAction<Person>
    data class OpenBook(val book: Book) : PersonShelfAction<Nothing>
    data class Order(val order: AuthorListOrder) : PersonShelfAction<Nothing>
    data class Menu(val book: Book, val action: BookQuickAction) : PersonShelfAction<Nothing>
    data class Reached(val id: String) : PersonShelfAction<Nothing>
    data object LoadMore : PersonShelfAction<Nothing>
    data object Refresh : PersonShelfAction<Nothing>
}

private val orders = listOf(AuthorListOrder.LOVED, AuthorListOrder.RECENT, AuthorListOrder.NAME)

/** Authors or narrators: a row of posters each by recency or love, or an A–Z list. */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun <Person : ShelvedPerson> PersonShelfPage(
    title: String,
    failureTitle: String,
    noFavoritesTitle: String,
    noFavoritesMessage: String,
    people: List<Person>,
    order: AuthorListOrder,
    isLoading: Boolean,
    errorMessage: String?,
    hasMore: Boolean,
    loadMoreFailed: Boolean,
    onAction: suspend (PersonShelfAction<Person>) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun send(action: PersonShelfAction<Person>) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }
    PullToRefreshBox(refreshing, onRefresh = {
        refreshing = true
        scope.launch {
            onAction(PersonShelfAction.Refresh)
            refreshing = false
        }
    }, Modifier.fillMaxSize()) {
        LazyColumn(
            Modifier.fillMaxSize(),
            contentPadding = PaddingValues(bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(if (order == AuthorListOrder.NAME) 0.dp else 26.dp),
        ) {
            item(key = "title") { LargeTitle(title) }
            item(key = "pills") {
                Box(Modifier.padding(vertical = 8.dp)) {
                    FilterPills(orders.map { FilterPill(it.name, it.pillLabel) }, order.name, { id ->
                        AuthorListOrder.entries.firstOrNull { it.name == id }?.let { send(PersonShelfAction.Order(it)) }
                    }, allLabel = null)
                }
            }
            if (order == AuthorListOrder.NAME) {
                letterSections(people).forEach { (letter, section) ->
                    stickyHeader(key = "letter-$letter") {
                        Text(
                            letter,
                            style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold),
                            color = Shiori.colors.label,
                            modifier = Modifier.fillMaxWidth().background(Shiori.colors.groupedBackground).padding(start = 20.dp, end = 20.dp, top = 16.dp, bottom = 2.dp),
                        )
                    }
                    items(section, key = { it.id }) { person ->
                        LaunchedEffect(person.id) { onAction(PersonShelfAction.Reached(person.id)) }
                        AlphabeticalRow(person) { send(PersonShelfAction.OpenPerson(person)) }
                    }
                }
            } else {
                items(people, key = { it.id }) { person ->
                    LaunchedEffect(person.id) { onAction(PersonShelfAction.Reached(person.id)) }
                    ShelfRow(person, showsHeart = order != AuthorListOrder.LOVED, ::send)
                }
            }
            if (hasMore) item(key = "more") { LoadMoreRow(loadMoreFailed, L("Chargement de la suite")) { onAction(PersonShelfAction.LoadMore) } }
        }
        if (people.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                when {
                    isLoading -> CircularProgressIndicator()
                    errorMessage != null -> FailureState(failureTitle, errorMessage) { onAction(PersonShelfAction.Refresh) }
                    order == AuthorListOrder.LOVED -> EmptyState("heart", noFavoritesTitle, noFavoritesMessage)
                }
            }
        }
    }
}

/** People under their index letter, "#" last. */
fun <Person : ShelvedPerson> letterSections(people: List<Person>): List<Pair<String, List<Person>>> =
    people.groupBy { it.indexLetter }.toList().sortedWith { left, right ->
        val leftHash = left.first == "#"
        val rightHash = right.first == "#"
        if (leftHash != rightHash) (if (leftHash) 1 else -1) else java.text.Collator.getInstance().compare(left.first, right.first)
    }

/** "Robin **Hobb**": the surname in bold when the catalogue knows it. */
fun personName(person: ShelvedPerson): AnnotatedString {
    val surname = person.surname
    if (surname.isNullOrEmpty() || !person.name.endsWith(surname)) return AnnotatedString(person.name)
    return buildAnnotatedString {
        append(person.name.dropLast(surname.length))
        withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(surname) }
    }
}

@Composable
private fun AlphabeticalRow(person: ShelvedPerson, onOpen: () -> Unit) {
    val colors = Shiori.colors
    Row(
        Modifier.fillMaxWidth().plainClickable(onClick = onOpen).padding(start = 20.dp, end = 28.dp, top = 6.dp, bottom = 6.dp),
        horizontalArrangement = Arrangement.spacedBy(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        AuthorAvatar(person.initials, person.portraitURL, size = 48.dp)
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            Text(personName(person), style = Shiori.type.body, color = colors.label, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f, fill = false))
            if (person.favorite) Icon(Symbol("heart.fill"), L("Préféré"), Modifier.size(13.dp), tint = colors.label)
        }
        Icon(Symbol("chevron.right"), null, Modifier.size(14.dp), tint = colors.tertiaryLabel)
    }
}

@Composable
private fun <Person : ShelvedPerson> ShelfRow(person: Person, showsHeart: Boolean, send: (PersonShelfAction<Person>) -> Unit) {
    val colors = Shiori.colors
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            Modifier.padding(horizontal = 20.dp).plainClickable { send(PersonShelfAction.OpenPerson(person)) },
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            AuthorAvatar(person.initials, person.portraitURL, size = 40.dp)
            Text(
                person.name,
                style = Shiori.type.title3.copy(fontWeight = FontWeight.Bold),
                color = colors.label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f, fill = false),
            )
            if (person.favorite && showsHeart) Icon(Symbol("heart.fill"), L("Préféré"), Modifier.size(13.dp), tint = colors.label)
            Icon(Symbol("chevron.right"), null, Modifier.size(16.dp), tint = colors.secondaryLabel)
            Spacer(Modifier.size(0.dp))
        }
        PosterRow(
            person.books.map { PosterRowItem(it, PosterLabel.of(it, PosterLabel.Context.RECENT)) },
            onMenu = { book, action -> send(PersonShelfAction.Menu(book, action)) },
        ) { send(PersonShelfAction.OpenBook(it)) }
    }
}

@Preview(showBackground = true)
@Composable
private fun PersonShelfPagePreview() = PreviewSurface {
    PersonShelfPage(
        title = "Auteurs",
        failureTitle = "Auteurs indisponibles",
        noFavoritesTitle = "Aucun auteur préféré",
        noFavoritesMessage = "Un cœur sur un auteur le place ici.",
        people = listOf(DebugFixtures.author),
        order = com.polyforms.shiori.features.authors.AuthorListOrder.RECENT,
        isLoading = false,
        errorMessage = null,
        hasMore = false,
        loadMoreFailed = false,
    ) {}
}
