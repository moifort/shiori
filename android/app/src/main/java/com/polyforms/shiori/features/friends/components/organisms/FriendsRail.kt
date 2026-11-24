package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.friends.FriendsFixtures
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.account.AccountAvatar
import com.polyforms.shiori.shared.book.PosterCover
import com.polyforms.shiori.shared.book.PosterLabel
import com.polyforms.shiori.shared.components.molecules.RowHeader
import com.polyforms.shiori.shared.components.molecules.RowHeaderStyle
import com.polyforms.shiori.shared.components.styles.plainClickable

/**
 * One rail of the Amis tab: covers as the Library tab draws them, each with its line, and in the
 * corner whose book it is when the page shows more than one friend.
 */
@Composable
fun FriendsRail(title: String, items: List<FriendsRailItem>, onOpen: (FriendsRailItem) -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RowHeader(title, Modifier.padding(horizontal = 20.dp), style = RowHeaderStyle.INLINE)
        LazyRow(contentPadding = PaddingValues(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(13.dp), verticalAlignment = Alignment.Top) {
            items(items, key = { it.id }) { item ->
                val description = listOfNotNull(item.book.title, item.label.caption, item.friendName).filter { it.isNotEmpty() }.joinToString(", ")
                Box(Modifier.plainClickable { onOpen(item) }.semantics(mergeDescendants = true) { contentDescription = description }) {
                    PosterCover(item.book, item.label)
                    item.friendName?.let { name -> FriendCoverTag(name, item.friendAvatar, Modifier.padding(6.dp)) }
                }
            }
        }
    }
}

/** A cover of a rail. [friendName] is null when the page shows one friend: the corner stays bare. */
data class FriendsRailItem(val id: String, val book: Book, val label: PosterLabel, val friendName: String?, val friendAvatar: AccountAvatar)

@Preview(showBackground = true)
@Composable
private fun FriendsRailPreview() = PreviewSurface(dark = true) {
    FriendsRail(
        "Lecture en cours",
        FriendsFixtures.shelf.reading.map {
            FriendsRailItem(it.id, it.book.book, PosterLabel.of(it.book.book, PosterLabel.Context.RECENT), it.friendName, it.book.ownerAvatar)
        },
    ) {}
}
