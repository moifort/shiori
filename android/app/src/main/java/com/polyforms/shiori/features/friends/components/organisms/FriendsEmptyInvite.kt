package com.polyforms.shiori.features.friends.components.organisms

import com.polyforms.shiori.shared.book.backdropFrame
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.DebugFixtures
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.FriendProfile
import com.polyforms.shiori.features.onboarding.LocalAccount
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.book.CoverBackdrop
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.atoms.AccountAvatarView
import com.polyforms.shiori.shared.components.atoms.AsyncActionButton
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.ActionLabel
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.ShioriTheme
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * The Amis tab without a friend: the reader's avatar among empty places, a line on what sharing
 * gives, the invitation, and what their friends will see of their shelf.
 */
@Composable
fun FriendsEmptyInvite(myShelf: FriendProfile?, isInviting: Boolean, onInvite: suspend () -> Unit, onOpenMyBook: (FriendBook) -> Unit, top: Dp = 0.dp) {
    val account = LocalAccount.current
    val shown = shownOf(myShelf)
    val ground = Shiori.colors.background
    Column(Modifier.fillMaxWidth().padding(bottom = 32.dp)) {
        Box(Modifier.fillMaxWidth()) {
            // iOS's 760 points raised by 300, under the bar's room [top].
            CoverBackdrop(shown.firstOrNull()?.book?.coverURL, Modifier.backdropFrame(top + 460.dp), fadeHeight = 160.dp, ground = ground)
            ShioriTheme(dark = true) {
                Column(Modifier.fillMaxWidth().padding(top = top).padding(horizontal = 20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(
                        Modifier.padding(top = 24.dp).clearAndSetSemantics {},
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Place(54.dp, faded = true)
                        Place(66.dp, faded = false)
                        Box(Modifier.border(3.dp, Color.White, CircleShape).padding(3.dp)) {
                            AccountAvatarView(account.avatar, account.firstName, 84.dp)
                        }
                        Place(66.dp, faded = false)
                        Place(54.dp, faded = true)
                    }
                    Text(
                        L("Lire, c’est mieux à plusieurs"),
                        style = Shiori.type.title.copy(fontWeight = FontWeight.Bold),
                        color = Shiori.colors.label,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 26.dp),
                    )
                    Text(
                        L("Invitez un ami : vous verrez ce qu’il lit, ce qu’il a adoré et ce qui l’attend sur sa pile. Il verra vos livres en retour."),
                        style = Shiori.type.callout,
                        color = Shiori.colors.secondaryLabel,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 10.dp).padding(horizontal = 16.dp),
                    )
                    AsyncActionButton(
                        outcome = {
                            onInvite()
                            null
                        },
                        modifier = Modifier.padding(top = 24.dp),
                        height = 44.dp,
                        enabled = !isInviting,
                    ) { ActionLabel(L("Inviter un ami"), "person.badge.plus", 44.dp) }
                }
            }
        }
        if (shown.isNotEmpty()) {
            Column(Modifier.fillMaxWidth().padding(top = 34.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                RowHeader(L("Ce qu’ils verront de vous"), Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
                LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp)) {
                    items(shown, key = { it.id }) { book ->
                        Box(Modifier.plainClickable { onOpenMyBook(book) }) {
                            PosterCover(book.book, PosterLabel.of(book.book, PosterLabel.Context.RECENT))
                        }
                    }
                }
            }
        }
    }
}

/** The reader's shelf as a friend first meets it: what they read now, what they hearted, what waits; each book once. */
private fun shownOf(myShelf: FriendProfile?): List<FriendBook> {
    myShelf ?: return emptyList()
    return (myShelf.reading + myShelf.favorites + myShelf.pile).distinctBy { it.id }.take(12)
}

/** An empty place beside the reader: a dashed circle around a plus. */
@Composable
private fun Place(size: Dp, faded: Boolean) {
    Box(
        Modifier
            .size(size)
            .alpha(if (faded) 0.6f else 1f)
            .background(Color.Black.copy(alpha = 0.25f), CircleShape)
            .drawBehind {
                val stroke = 1.5.dp.toPx()
                drawCircle(
                    Color.White.copy(alpha = 0.35f),
                    radius = this.size.minDimension / 2 - stroke / 2,
                    center = Offset(this.size.width / 2, this.size.height / 2),
                    style = Stroke(stroke, pathEffect = PathEffect.dashPathEffect(floatArrayOf(4.dp.toPx(), 3.dp.toPx()))),
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        Icon(Symbol("plus"), null, Modifier.size(size * 0.28f), tint = Shiori.colors.secondaryLabel)
    }
}

@Preview(showBackground = true)
@Composable
private fun FriendsEmptyInvitePreview() = PreviewSurface(dark = true) {
    FriendsEmptyInvite(DebugFixtures.myShelf, isInviting = false, onInvite = {}, onOpenMyBook = {})
}
