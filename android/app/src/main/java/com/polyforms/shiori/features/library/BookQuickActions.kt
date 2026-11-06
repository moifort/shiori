package com.polyforms.shiori.features.library

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.authors.AuthorDestination
import com.polyforms.shiori.features.book.components.pages.RatingPromptSheet
import com.polyforms.shiori.features.home.components.organisms.FinishedBookSheet
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus
import com.polyforms.shiori.shared.book.BookQuickAction
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.platform.ShioriAlert
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.launch

/** Carries out a cover's quick actions: the writes, and the sheets some of them open. */
class BookQuickActionsState {
    var finishing by mutableStateOf<Book?>(null)
    var rating by mutableStateOf<Book?>(null)
    var removing by mutableStateOf<Book?>(null)
}

@Composable
fun rememberBookQuickActions(client: LibraryClient, open: (LibraryDestination) -> Unit): (Book, BookQuickAction) -> Unit {
    val state = remember { BookQuickActionsState() }
    val scope = rememberCoroutineScope()
    fun write(work: suspend () -> Unit) {
        scope.launch {
            try {
                work()
            } catch (error: Exception) {
                if (!isCancellation(error)) reportError(error)
            }
        }
    }
    state.finishing?.let { book ->
        FinishedBookSheet(book, onDone = { stars ->
            state.finishing = null
            write {
                client.setStatus(book.id, ReadingStatus.READ)
                if (stars != null) client.rate(book.id, stars)
            }
        }, onCancel = { state.finishing = null })
    }
    state.rating?.let { book ->
        RatingPromptSheet(book.rating, { state.rating = null }) { stars ->
            state.rating = null
            write { client.rate(book.id, stars) }
        }
    }
    state.removing?.let { book ->
        ShioriAlert(
            L("Supprimer ce livre ?"),
            L("Sa note et ses commentaires partent avec lui."),
            onDismiss = { state.removing = null },
            confirm = L("Supprimer"),
            dismissLabel = L("Annuler"),
            destructive = true,
            onConfirm = {
                state.removing = null
                write { client.delete(book.id) }
            },
        )
    }
    return { book, action ->
        when (action) {
            is BookQuickAction.SetStatus -> if (action.status == ReadingStatus.READ) state.finishing = book else write { client.setStatus(book.id, action.status) }
            BookQuickAction.ToggleFavorite -> write { client.setFavorite(book.id, !book.favorite) }
            BookQuickAction.Rate -> state.rating = book
            is BookQuickAction.OpenSeries -> open(LibraryDestination.Series(action.id))
            is BookQuickAction.OpenAuthor -> open(LibraryDestination.Author(AuthorDestination(action.key, action.name)))
            BookQuickAction.Remove -> state.removing = book
        }
    }
}
