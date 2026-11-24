package com.polyforms.shiori.features.friends

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.nestedscroll.nestedScroll
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.AppRouter
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.platform.NavigationStack
import com.polyforms.shiori.shared.platform.ScrollAwayBar
import com.polyforms.shiori.shared.platform.ShioriSheet
import com.polyforms.shiori.shared.platform.rememberScrollAwayState

/**
 * The Amis tab, connected: every chosen friend's shelf as one set of rails.
 *
 * Placeholder of the Android catch-up's foundation: the Friends lot replaces this body with the
 * port of iOS's `FriendsScreen`, keeping the signature. `friendRequest` is the friend a Découvrir
 * pill asked for, `welcomedFriend` the one an invitation just joined; both are cleared once shown.
 */
@Composable
fun FriendsScreen(friendRequest: String?, welcomedFriend: String?, onFriendShown: () -> Unit) {
    val bar = rememberScrollAwayState()
    Box(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).nestedScroll(bar.connection)) {
        Box(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(top = 120.dp)) {
            EmptyState("person.2", L("Lire, c’est mieux à plusieurs"), L("Invitez un ami : vous verrez ce qu’il lit, ce qu’il a adoré et ce qui l’attend sur sa pile. Il verra vos livres en retour."))
        }
        ScrollAwayBar(L("Amis"), bar)
    }
}

/**
 * What the app shows over every tab for the friends: the invitation a tapped link brought, and,
 * until the Friends lot removes it, the Partagé sheet the home still opens. The Friends lot
 * rewrites this body (an invitation is accepted at once on iOS), keeping the signature.
 */
@Composable
fun FriendsOverlays(router: AppRouter) {
    if (router.showShared) {
        ShioriSheet({ router.showShared = false }) {
            Box(Modifier.fillMaxSize()) { NavigationStack { SharedScreen() } }
        }
    }
    // The invitation is asked about rather than accepted: the link came from somewhere the reader
    // does not control, and accepting opens their library to whoever sent it.
    router.invitation?.let { InvitationAcceptSheet(it, { router.invitation = null }) }
}
