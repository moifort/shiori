package com.polyforms.shiori.features.friends.components.pages

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
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
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.friends.FavoritesSharing
import com.polyforms.shiori.features.friends.Friend
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.FriendProfile
import com.polyforms.shiori.features.friends.ReadingChallenge
import com.polyforms.shiori.features.friends.components.organisms.FriendRow
import com.polyforms.shiori.features.friends.components.organisms.ReadingChallengeCard
import com.polyforms.shiori.features.news.components.organisms.SwipeMenuBox
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.FormRow
import com.polyforms.shiori.shared.components.styles.FormSection
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriDivider
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable
import com.polyforms.shiori.shared.platform.LargeTitle
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry
import kotlinx.coroutines.launch
import java.time.LocalDate
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.foundation.layout.Row
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface

/** Everything the Partagé page can ask for. */
sealed interface SharedAction {
    /** A cover of a row: a friend's book, or the reader's own when `friend` is null. */
    data class OpenBook(val book: FriendBook, val friend: Friend?) : SharedAction
    data object OpenMyPage : SharedAction
    data class OpenFriend(val friend: Friend) : SharedAction
    data object Invite : SharedAction
    data object EnterCode : SharedAction
    data class AskToRemove(val friend: Friend) : SharedAction
    data class ShareFavorites(val text: String) : SharedAction
    data class CopyFavorites(val text: String) : SharedAction
    data object Refresh : SharedAction
}

/**
 * The Partagé screen, drawn: the reader at the top, as the row their friends see in their own
 * list, the year's reading challenge, then who the reader shares their library with.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SharedPage(
    myShelf: FriendProfile?,
    friends: List<Friend>,
    isWaiting: Boolean,
    loadFailed: String?,
    isInviting: Boolean,
    onAction: suspend (SharedAction) -> Unit,
) {
    val scope = rememberCoroutineScope()
    fun act(action: SharedAction) {
        scope.launch { onAction(action) }
    }
    var refreshing by remember { mutableStateOf(false) }
    when {
        loadFailed != null -> Box(Modifier.fillMaxSize().statusBarsPadding(), contentAlignment = Alignment.Center) {
            FailureState(L("Amis indisponibles"), loadFailed) { onAction(SharedAction.Refresh) }
        }
        isWaiting -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        else -> PullToRefreshBox(refreshing, onRefresh = {
            refreshing = true
            scope.launch {
                onAction(SharedAction.Refresh)
                refreshing = false
            }
        }, Modifier.fillMaxSize()) {
            LazyColumn(Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 40.dp), verticalArrangement = Arrangement.spacedBy(24.dp)) {
                item(key = "title") { LargeTitle(L("Partagé")) }
                if (myShelf != null) {
                    item(key = "me") {
                        FormSection(L("Vous")) {
                            Box(Modifier.plainClickable { act(SharedAction.OpenMyPage) }.padding(vertical = 12.dp)) {
                                FriendRow(Friend.seenByFriends(myShelf)) { act(SharedAction.OpenBook(it, null)) }
                            }
                            FavoritesSharing.text(myShelf)?.let { text ->
                                ShioriDivider(Modifier.padding(start = 16.dp))
                                var expanded by remember { mutableStateOf(false) }
                                Box {
                                    ActionRow("square.and.arrow.up", L("Partager mes favoris"), divider = false) { expanded = true }
                                    MenuEntries(
                                        listOf(
                                            MenuEntry.Item(L("Envoyer…"), "paperplane") { act(SharedAction.ShareFavorites(text)) },
                                            MenuEntry.Item(L("Copier la liste"), "doc.on.doc") { act(SharedAction.CopyFavorites(text)) },
                                        ),
                                        expanded,
                                    ) { expanded = false }
                                }
                            }
                        }
                    }
                }
                // Only a race once there is somebody to race against.
                if (myShelf != null && friends.isNotEmpty()) {
                    item(key = "challenge") {
                        FormSection(L("Défi lecture %@", LocalDate.now().year.toString())) {
                            ReadingChallengeCard(ReadingChallenge(Friend.seenByFriends(myShelf), friends))
                        }
                    }
                }
                if (friends.isEmpty()) {
                    item(key = "invite-prompt") {
                        FormSection {
                            Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(L("Partagez vos lectures"), style = Shiori.type.headline, color = Shiori.colors.label)
                                Text(
                                    L("Invitez un ami : vous verrez sa bibliothèque et il verra la vôtre. Chacun pourra piocher des livres chez l'autre."),
                                    style = Shiori.type.subheadline,
                                    color = Shiori.colors.secondaryLabel,
                                )
                            }
                            ShioriDivider(Modifier.padding(start = 16.dp))
                            ActionRow("person.badge.plus", L("Inviter un ami"), enabled = !isInviting) { act(SharedAction.Invite) }
                            ActionRow("arrow.down.circle", L("J'ai reçu une invitation"), divider = false) { act(SharedAction.EnterCode) }
                        }
                    }
                } else {
                    item(key = "friends") {
                        FormSection(L("Mes amis")) {
                            ActionRow("person.badge.plus", L("Envoyer une invitation"), enabled = !isInviting) { act(SharedAction.Invite) }
                            friends.forEachIndexed { index, friend ->
                                SwipeMenuBox(
                                    listOf(MenuEntry.Item(L("Retirer"), "person.badge.minus", destructive = true) { act(SharedAction.AskToRemove(friend)) }),
                                    onTap = { act(SharedAction.OpenFriend(friend)) },
                                ) {
                                    Box(Modifier.fillMaxWidth().padding(vertical = 12.dp)) {
                                        FriendRow(friend) { act(SharedAction.OpenBook(it, friend)) }
                                    }
                                }
                                if (index < friends.lastIndex) ShioriDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}

/** A row that acts: its glyph and its title in the accent colour. */
@Composable
private fun ActionRow(symbol: String, title: String, enabled: Boolean = true, divider: Boolean = true, onClick: () -> Unit) {
    FormRow(Modifier.alpha(if (enabled) 1f else 0.4f), divider = divider, onClick = if (enabled) onClick else null) {
        Icon(Symbol(symbol), null, Modifier.size(20.dp), tint = Shiori.colors.accent)
        Text(title, style = Shiori.type.body, color = Shiori.colors.accent)
    }
}

@Preview(showBackground = true)
@Composable
private fun SharedPagePreview() = PreviewSurface {
    SharedPage(DebugFixtures.myShelf, DebugFixtures.friends, isWaiting = false, loadFailed = null, isInviting = false) {}
}
