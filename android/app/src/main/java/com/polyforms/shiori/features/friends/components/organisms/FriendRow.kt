package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.features.friends.Friend
import com.polyforms.shiori.features.friends.FriendBook
import com.polyforms.shiori.features.friends.RecentActivity
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.organisms.CoverTile
import com.polyforms.shiori.shared.components.styles.Shiori
import com.polyforms.shiori.shared.components.styles.Symbol
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * A friend as the Partagé list draws them: the initials, the name, their shelf in figures in the
 * corner, and under it what moved lately on their shelf. The invitation sheets draw the same row,
 * so what is being shared reads the way it will be seen.
 */
@Composable
fun FriendRow(friend: Friend, modifier: Modifier = Modifier, inset: Dp = 16.dp, onOpen: ((FriendBook) -> Unit)? = null) {
    val colors = Shiori.colors
    Column(modifier.fillMaxWidth().padding(vertical = 2.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(Modifier.padding(horizontal = inset), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            Box(Modifier.size(40.dp).background(colors.accent.copy(alpha = 0.15f), CircleShape), contentAlignment = Alignment.Center) {
                Text(friend.initials, style = Shiori.type.subheadline.copy(fontWeight = FontWeight.SemiBold), color = colors.accent)
            }
            Text(
                friend.displayName,
                style = Shiori.type.body.copy(fontWeight = FontWeight.Medium),
                color = colors.label,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
                Figure("heart", friend.favoriteCount)
                Figure("book", friend.readingCount)
                Figure("book.pages", friend.bookCount)
            }
        }
        val recent = friend.recentActivity.filter { it.isRecent() }
        if (recent.isNotEmpty()) RecentActivityStrip(recent, inset, onOpen)
    }
}

@Composable
private fun Figure(symbol: String, count: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp), verticalAlignment = Alignment.CenterVertically) {
        Icon(Symbol(symbol), null, Modifier.size(12.dp), tint = Shiori.colors.secondaryLabel)
        Text("$count", style = Shiori.type.caption, color = Shiori.colors.secondaryLabel)
    }
}

/**
 * A friend's recent activity as up to five covers scrolled sideways, each with what happened
 * under it: how far a recording got, else "En cours", "Lu", "Favori", "Ajouté" or "Abandonné".
 */
@Composable
fun RecentActivityStrip(activities: List<RecentActivity>, inset: Dp = 0.dp, onOpen: ((FriendBook) -> Unit)? = null) {
    LazyRow(
        contentPadding = PaddingValues(start = inset, end = inset, top = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        items(activities.take(5), key = { it.id }) { activity ->
            CoverTile(
                activity.book.book,
                caption(activity),
                Modifier.then(if (onOpen != null) Modifier.plainClickable { onOpen(activity.book) } else Modifier),
                width = 72.dp,
            )
        }
    }
}

private fun caption(activity: RecentActivity): String = when (activity.kind) {
    RecentActivity.Kind.READING -> activity.book.book.listeningProgressLabel?.let { L("%@ écouté", it) } ?: L("En cours")
    RecentActivity.Kind.FINISHED -> L("Lu")
    RecentActivity.Kind.HEARTED -> L("Favori")
    RecentActivity.Kind.ADDED -> L("Ajouté")
    RecentActivity.Kind.DROPPED -> L("Abandonné")
}

/** What an invitation shares, in one card: the row the other reader sees in their list. */
@Composable
fun SharedSummary(friend: Friend, heading: String? = L("Ce que vous partagez")) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        if (heading != null) Text(heading, style = Shiori.type.footnote, color = Shiori.colors.secondaryLabel)
        Box(Modifier.fillMaxWidth().background(Shiori.colors.tertiaryFill, RoundedCornerShape(14.dp)).padding(vertical = 12.dp)) {
            FriendRow(friend)
        }
    }
}
