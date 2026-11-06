package com.polyforms.shiori.features.book.components.organisms

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.discover.AwaitedEdition
import com.polyforms.shiori.features.discover.EditionOffer
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.platform.MenuEntry
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.platform.ToolbarMenuButton

sealed interface BookMenuAction {
    data object Edit : BookMenuAction
    data object ChooseCover : BookMenuAction
    data object JoinSeries : BookMenuAction
    data object Recommend : BookMenuAction
    data class AwaitEdition(val format: ReleaseFormat) : BookMenuAction
    data class StopAwaiting(val edition: AwaitedEdition) : BookMenuAction
    data class SetStatus(val status: ReadingStatus) : BookMenuAction
    data object ToggleHidden : BookMenuAction
    data object Delete : BookMenuAction
}

/** The book page's `…`: edit, cover, saga, recommendation, awaiting, sharing, drop, delete. */
@Composable
fun BookActionsMenu(book: Book, offer: EditionOffer, onAction: (BookMenuAction) -> Unit) {
    var confirmDelete by remember { mutableStateOf(false) }
    val entries = buildList {
        add(MenuEntry.Item(L("Modifier"), "pencil") { onAction(BookMenuAction.Edit) })
        add(MenuEntry.Item(L("Couverture"), "photo") { onAction(BookMenuAction.ChooseCover) })
        if (book.series == null) add(MenuEntry.Item(L("Ajouter à une série"), "square.stack") { onAction(BookMenuAction.JoinSeries) })
        add(MenuEntry.Item(L("Conseillé par…"), "person.badge.plus") { onAction(BookMenuAction.Recommend) })
        offer.awaitable.forEach { format ->
            add(MenuEntry.Item(format.awaitLabel, if (format == ReleaseFormat.AUDIOBOOK) "headphones" else "character.book.closed") {
                onAction(BookMenuAction.AwaitEdition(format))
            })
        }
        offer.awaited.forEach { edition ->
            val title = if (edition.format == ReleaseFormat.AUDIOBOOK) L("Ne plus guetter en audio") else L("Ne plus guetter en français")
            add(MenuEntry.Item(title, "bell.slash") { onAction(BookMenuAction.StopAwaiting(edition)) })
        }
        add(MenuEntry.Item(L("Ne pas partager"), "eye.slash", checked = book.hidden) { onAction(BookMenuAction.ToggleHidden) })
        if (book.status == ReadingStatus.DROPPED) {
            add(MenuEntry.Item(L("Reprendre"), "arrow.uturn.backward") { onAction(BookMenuAction.SetStatus(ReadingStatus.READING)) })
        } else {
            add(MenuEntry.Item(L("Abandonner"), "hand.thumbsdown") { onAction(BookMenuAction.SetStatus(ReadingStatus.DROPPED)) })
        }
        add(MenuEntry.Item(L("Supprimer"), "trash", destructive = true) { confirmDelete = true })
    }
    ToolbarMenuButton(L("Plus d'actions"), "ellipsis", entries)
    if (confirmDelete) {
        ShioriAlert(
            L("Supprimer ce livre ?"),
            L("Votre note sera perdue. Cette action est définitive."),
            onDismiss = { confirmDelete = false },
            confirm = L("Supprimer"),
            dismissLabel = L("Annuler"),
            destructive = true,
            onConfirm = {
                confirmDelete = false
                onAction(BookMenuAction.Delete)
            },
        )
    }
}
