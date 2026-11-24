package com.polyforms.shiori.features.friends.components.organisms

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.features.friends.CopiedStatus
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.components.molecules.AddMenuButton
import com.polyforms.shiori.shared.components.molecules.AddMenuSize
import com.polyforms.shiori.shared.components.molecules.EditionWatch
import com.polyforms.shiori.shared.components.molecules.OwnedCapsule
import com.polyforms.shiori.shared.components.molecules.TakenState
import com.polyforms.shiori.shared.platform.MenuEntry

/**
 * The first button of a friend's book hero, where the reader's own book has its next step: "+
 * Ajouter", onto the pile, or among the books read, in print or as a recording, or onto the wish
 * list — a reader who never listens takes a friend's recording as a book, and a printed book is
 * offered heard once Audible confirms it sells it. Its edition in the app's language may be awaited
 * from here too, one action at a time. Once the reader holds the book it says so, "✓ Ajouté" on
 * glass, and still opens what is left to await.
 */
@Composable
fun FriendBookAddMenu(
    formats: List<BookFormat>,
    owned: Boolean,
    awaitable: List<ReleaseFormat>,
    onAdd: (CopiedStatus, BookFormat) -> Unit,
    onAwait: (ReleaseFormat) -> Unit,
    modifier: Modifier = Modifier,
    wished: Boolean = false,
    onWish: () -> Unit = {},
    /** What may be awaited and what is: an edition awaited is the action the "+ Ajouter" says. */
    watch: EditionWatch? = null,
    /** The capsule of an edition awaited pressed: it is given up. */
    onStopAwaiting: (ReleaseFormat) -> Unit = {},
) {
    if (owned) {
        // "✓ Ajouté" on glass, which still opens the editions left to await, and takes no tap once none is.
        OwnedCapsule(modifier, AddMenuSize.PAGE, if (awaitable.isEmpty()) emptyList() else bookAddMenu(formats, true, awaitable, wished, onAdd, onWish, onAwait))
        return
    }
    val done: TakenState? = when {
        wished -> TakenState.Wished
        else -> watch?.offered?.firstOrNull { it in watch.awaited }?.let { TakenState.Awaited(it) }
    }
    AddMenuButton(
        bookAddMenu(formats, false, awaitable, wished, onAdd, onWish, onAwait),
        modifier,
        size = AddMenuSize.PAGE,
        done = done,
        isDisabled = formats.isEmpty() && awaitable.isEmpty(),
        onUndo = {
            when (done) {
                TakenState.Wished -> onWish()
                is TakenState.Awaited -> onStopAwaiting(done.format)
                else -> Unit
            }
        },
    )
}

/**
 * What a book the reader does not hold may become: onto the pile or among the books read, in each
 * format they may take it in; onto the wishlist; its edition in the app's language awaited.
 */
fun bookAddMenu(
    formats: List<BookFormat>,
    owned: Boolean,
    awaitable: List<ReleaseFormat>,
    wished: Boolean,
    onAdd: (CopiedStatus, BookFormat) -> Unit,
    onWish: () -> Unit,
    onAwait: (ReleaseFormat) -> Unit,
): List<MenuEntry> = buildList {
    if (!owned) {
        formats.forEach { format ->
            val audio = format == BookFormat.AUDIOBOOK
            add(MenuEntry.Item("${format.label} · ${if (audio) L("À écouter") else L("À lire")}", "bookmark.fill") { onAdd(CopiedStatus.TO_READ, format) })
            add(MenuEntry.Item("${format.label} · ${if (audio) L("Déjà écouté") else L("Déjà lu")}", "checkmark") { onAdd(CopiedStatus.READ, format) })
            add(MenuEntry.Divider)
        }
        add(MenuEntry.Item(L("Ajouter à la liste d'envies"), if (wished) "checkmark" else "bookmark") { if (!wished) onWish() })
    }
    if (awaitable.isNotEmpty()) {
        if (!owned) add(MenuEntry.Divider)
        awaitable.forEach { add(MenuEntry.Item(it.awaitLabel, if (it == ReleaseFormat.AUDIOBOOK) "headphones" else "binoculars") { onAwait(it) }) }
    }
}

@Preview(showBackground = true)
@Composable
private fun FriendBookAddMenuPreview() = PreviewSurface(dark = true) {
    Column(Modifier.background(Color.Black).padding(20.dp), verticalArrangement = Arrangement.spacedBy(20.dp)) {
        FriendBookAddMenu(listOf(BookFormat.BOOK, BookFormat.AUDIOBOOK), owned = false, awaitable = listOf(ReleaseFormat.AUDIOBOOK), onAdd = { _, _ -> }, onAwait = {})
        FriendBookAddMenu(listOf(BookFormat.BOOK), owned = false, awaitable = emptyList(), onAdd = { _, _ -> }, onAwait = {}, wished = true)
        FriendBookAddMenu(listOf(BookFormat.BOOK), owned = true, awaitable = emptyList(), onAdd = { _, _ -> }, onAwait = {})
    }
}
