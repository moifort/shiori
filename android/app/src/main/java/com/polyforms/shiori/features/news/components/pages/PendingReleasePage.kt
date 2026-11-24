package com.polyforms.shiori.features.news.components.pages

import com.polyforms.shiori.shared.platform.pageEndRoom

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.polyforms.shiori.PreviewSurface
import com.polyforms.shiori.features.news.NewsFixtures
import com.polyforms.shiori.features.news.UpcomingRelease
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.book.BookHero
import com.polyforms.shiori.shared.components.molecules.EmptyState
import com.polyforms.shiori.shared.components.molecules.FailureState
import com.polyforms.shiori.shared.components.styles.Shiori

/** What a release opening is waiting for. */
sealed interface PendingReleasePhase {
    data object Loading : PendingReleasePhase

    /** The release watch no longer lists it. */
    data object Missing : PendingReleasePhase

    /** The watch could not be read: why, and a retry. */
    data class Failed(val message: String) : PendingReleasePhase
}

/**
 * A release's page while it opens: drawn in the frame of the tap with what the list knew of it —
 * cover, title, authors, date — and a loader where its page will be. Pure: `UpcomingReleaseScreen`
 * says what it is waiting for.
 */
@Composable
fun PendingReleasePage(release: UpcomingRelease, phase: PendingReleasePhase, onRetry: suspend () -> Unit = {}) {
    Column(Modifier.fillMaxSize().background(Shiori.colors.groupedBackground).verticalScroll(rememberScrollState()).padding(bottom = pageEndRoom())) {
        BookHero(release.cover, showsLength = false, releaseDate = release.date, countdown = release.date?.let { ReleaseDateText.countdown(it) })
        Box(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 32.dp), contentAlignment = Alignment.Center) {
            when (phase) {
                PendingReleasePhase.Loading -> CircularProgressIndicator()
                PendingReleasePhase.Missing -> EmptyState("calendar.badge.exclamationmark", L("Sortie introuvable"), L("Cette sortie n'est plus annoncée."))
                is PendingReleasePhase.Failed -> FailureState(L("Sortie indisponible"), phase.message, retry = onRetry)
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun PendingReleasePageLoadingPreview() = PreviewSurface(dark = true) { PendingReleasePage(NewsFixtures.authorRelease, PendingReleasePhase.Loading) }

@Preview(showBackground = true)
@Composable
private fun PendingReleasePageMissingPreview() = PreviewSurface(dark = true) { PendingReleasePage(NewsFixtures.authorRelease, PendingReleasePhase.Missing) }

@Preview(showBackground = true)
@Composable
private fun PendingReleasePageFailedPreview() = PreviewSurface(dark = true) {
    PendingReleasePage(NewsFixtures.authorRelease, PendingReleasePhase.Failed("La connexion Internet semble interrompue."))
}
