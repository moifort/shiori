package com.polyforms.shiori.shared.book

import android.content.Intent
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.platform.MenuEntries
import com.polyforms.shiori.shared.platform.MenuEntry

/** What a long press on a cover offers. */
sealed interface BookQuickAction {
    data class SetStatus(val status: ReadingStatus) : BookQuickAction
    data object ToggleFavorite : BookQuickAction
    data object Rate : BookQuickAction
    data class OpenSeries(val id: String) : BookQuickAction
    data class OpenAuthor(val key: String, val name: String) : BookQuickAction
    data object Remove : BookQuickAction
}

/**
 * A cover that opens its book on a tap and its quick actions on a long press, as iOS's context
 * menu: the next status, the heart, the stars, its saga and author, sharing, removing.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun BookContextMenuBox(
    book: Book,
    onOpen: () -> Unit,
    onAction: ((BookQuickAction) -> Unit)?,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val haptics = LocalHapticFeedback.current
    Box(
        modifier.combinedClickable(
            interactionSource = remember { MutableInteractionSource() },
            indication = null,
            onClick = onOpen,
            onLongClick = onAction?.let {
                {
                    haptics.performHapticFeedback(HapticFeedbackType.LongPress)
                    expanded = true
                }
            },
        ),
    ) {
        content()
        if (onAction != null) {
            val entries = buildList {
                when (book.status) {
                    ReadingStatus.TO_READ -> add(MenuEntry.Item(if (book.format == BookFormat.AUDIOBOOK) L("Commencer l'écoute") else L("Commencer la lecture"), "book") { onAction(BookQuickAction.SetStatus(ReadingStatus.READING)) })
                    ReadingStatus.READING -> {
                        add(MenuEntry.Item(L("J'ai fini ce livre"), "checkmark") { onAction(BookQuickAction.SetStatus(ReadingStatus.READ)) })
                        add(MenuEntry.Item(L("Abandonner"), "hand.thumbsdown") { onAction(BookQuickAction.SetStatus(ReadingStatus.DROPPED)) })
                    }
                    ReadingStatus.READ -> add(MenuEntry.Item(L("Relire"), "arrow.counterclockwise") { onAction(BookQuickAction.SetStatus(ReadingStatus.READING)) })
                    ReadingStatus.DROPPED -> add(MenuEntry.Item(L("Reprendre la lecture"), "book") { onAction(BookQuickAction.SetStatus(ReadingStatus.READING)) })
                }
                add(MenuEntry.Item(if (book.favorite) L("Retirer des coups de cœur") else L("Coup de cœur"), if (book.favorite) "heart.slash" else "heart") { onAction(BookQuickAction.ToggleFavorite) })
                add(MenuEntry.Item(L("Noter"), "star") { onAction(BookQuickAction.Rate) })
                add(MenuEntry.Divider)
                book.series?.let { s -> add(MenuEntry.Item(L("Voir la série"), "square.stack") { onAction(BookQuickAction.OpenSeries(s.id)) }) }
                val author = book.authors.firstOrNull()
                val key = book.authorKeys?.firstOrNull()
                if (author != null && key != null) add(MenuEntry.Item(L("Voir l'auteur"), "author") { onAction(BookQuickAction.OpenAuthor(key, author)) })
                add(MenuEntry.Item(L("Partager"), "square.and.arrow.up") {
                    val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, "${book.title} — ${book.authorLine}")
                    context.startActivity(Intent.createChooser(send, null))
                })
                add(MenuEntry.Divider)
                add(MenuEntry.Item(L("Supprimer"), "trash", destructive = true) { onAction(BookQuickAction.Remove) })
            }
            MenuEntries(entries, expanded) { expanded = false }
        }
    }
}
