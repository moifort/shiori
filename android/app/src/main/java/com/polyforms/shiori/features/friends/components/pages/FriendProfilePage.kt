package com.polyforms.shiori.features.friends.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.pulltorefresh.PullToRefreshBox
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.discover.components.organisms.DiscoverSummaryRow
import com.polyforms.shiori.features.discover.components.organisms.SummaryCoverWidth
import com.polyforms.shiori.features.friends.Friend
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.FriendProfile
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.components.atoms.tint
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.organisms.BookCover
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import kotlinx.coroutines.launch

/** Everything a friend's page can ask for. */
sealed interface FriendProfileAction {
    data class OpenBook(val book: FriendBook) : FriendProfileAction
    data object OpenLibrary : FriendProfileAction
    data object Refresh : FriendProfileAction
}

/** "1 livre", "4 livres". */
internal fun bookCountLine(count: Int) = if (count == 1) L("1 livre") else L("%lld livres", count)

/**
 * One friend's shelf, summed up as Découvrir sums up its books: their hearts, their pile, each
 * over a strip of its covers, then their whole library behind a line that opens it. Read-only:
 * books marked "do not share" are absent, and no reading note is drawn.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun FriendProfilePage(
    friend: Friend,
    profile: FriendProfile?,
    isPreview: Boolean,
    isLoading: Boolean,
    errorMessage: String?,
    onAction: suspend (FriendProfileAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: FriendProfileAction) {
        scope.launch { onAction(action) }
    }
    val colors = Shiori.colors
    var refreshing by remember { mutableStateOf(false) }
    when {
        isLoading && profile == null -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        profile != null && !profile.isEmpty -> PullToRefreshBox(refreshing, onRefresh = {
            refreshing = true
            scope.launch {
                onAction(FriendProfileAction.Refresh)
                refreshing = false
            }
        }, Modifier.fillMaxSize()) {
            LazyColumn(Modifier.fillMaxSize().statusBarsPadding(), contentPadding = PaddingValues(top = 72.dp, bottom = 40.dp)) {
                item(key = "summary") {
                    FormSection {
                        if (profile.favorites.isNotEmpty()) {
                            DiscoverSummaryRow(
                                if (isPreview) L("Mes favoris") else L("Ses favoris"),
                                bookCountLine(friend.favoriteCount),
                                symbol = "heart.fill",
                                tint = colors.red,
                            ) { covers(profile.favorites) { act(FriendProfileAction.OpenBook(it)) } }
                            ShioriDivider()
                        }
                        if (profile.pile.isNotEmpty()) {
                            DiscoverSummaryRow(
                                if (isPreview) L("Ma pile à lire") else L("Sa pile à lire"),
                                bookCountLine(friend.toReadCount),
                                symbol = "bookmark.fill",
                                tint = ReadingStatus.TO_READ.tint,
                            ) { covers(profile.pile) { act(FriendProfileAction.OpenBook(it)) } }
                            ShioriDivider()
                        }
                        Row(Modifier.fillMaxWidth().plainClickable { act(FriendProfileAction.OpenLibrary) }.padding(end = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                            DiscoverSummaryRow(L("Bibliothèque"), libraryLine(friend, profile), Modifier.weight(1f))
                            Icon(Symbol("chevron.right"), null, Modifier.size(12.dp), tint = colors.tertiaryLabel)
                        }
                    }
                }
            }
        }
        errorMessage != null -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Bibliothèque indisponible"), errorMessage) { onAction(FriendProfileAction.Refresh) }
        }
        else -> Box(Modifier.fillMaxSize().padding(24.dp), contentAlignment = Alignment.Center) {
            Text(L("Aucun livre n'a été ajouté à cette bibliothèque."), style = Shiori.type.body, color = colors.secondaryLabel, textAlign = TextAlign.Center)
        }
    }
}

/** "2 séries · 80 livres · 3 en cours", the sagas and the books in progress left out at zero. */
private fun libraryLine(friend: Friend, profile: FriendProfile): String = buildList {
    if (profile.sagas.isNotEmpty()) add(if (profile.sagas.size == 1) L("1 série") else L("%lld séries", profile.sagas.size))
    add(bookCountLine(profile.bookCount))
    if (friend.readingCount > 0) add(L("%lld en cours", friend.readingCount))
}.joinToString(" · ")

private fun LazyListScope.covers(books: List<FriendBook>, onOpen: (FriendBook) -> Unit) {
    items(books, key = { it.id }) { entry ->
        Box(Modifier.plainClickable { onOpen(entry) }) { BookCover(entry.book, SummaryCoverWidth, formatBadgeSize = 22.dp) }
    }
}
