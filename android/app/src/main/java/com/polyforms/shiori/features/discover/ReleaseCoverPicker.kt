package com.polyforms.shiori.features.discover

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.CoverChoice
import com.polyforms.shiori.features.book.components.pages.CoverPickerSheet
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.reportError

/**
 * The cover picker of a book's "…" menu, for a book nobody here holds — a wish, an edition
 * awaited, a discovery, a winner, a volume announced: the covers found for its release, the one
 * drawn first. The cover picked is the release's, drawn for every reader in every list.
 */
@Composable
fun ReleaseCoverPicker(
    book: Book,
    releaseKey: String,
    onDismiss: () -> Unit,
    client: ReleaseCoverClient = ReleaseCoverClient.live,
    onChosen: (String) -> Unit,
) {
    var choices by remember { mutableStateOf<List<CoverChoice>?>(null) }
    var loadFailed by remember { mutableStateOf<String?>(null) }
    LaunchedEffect(releaseKey) {
        try {
            choices = client.choices(releaseKey, book.coverURL)
        } catch (error: Exception) {
            loadFailed = reportError(error)
        }
    }
    CoverPickerSheet(book, choices, loadFailed, onDismiss) { choice ->
        try {
            onChosen(client.choose(releaseKey, choice.url))
            null
        } catch (error: ApiError.Domain) {
            // The link to a shop's page, pasted for its cover: the reader's slip, nothing for Sentry.
            if (error.code == "COVER_NOT_AN_IMAGE") {
                L("Cette adresse mène à une page, pas à une image. Ouvrez l'image de la couverture seule, puis copiez son adresse.")
            } else {
                reportError(error)
            }
        } catch (error: Exception) {
            reportError(error)
        }
    }
}
