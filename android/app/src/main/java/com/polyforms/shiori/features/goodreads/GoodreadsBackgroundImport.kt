package com.polyforms.shiori.features.goodreads

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * A Goodreads import under way, kept beyond the screen that started it: the books are written in
 * one request, then their covers are sought a pass at a time while the app is open. The
 * onboarding's checklist and the import's progress page both read it. Once the app is closed the
 * server's scheduled pass (`/admin/seek-goodreads-covers`, every quarter of an hour) seeks the
 * rest.
 */
object GoodreadsBackgroundImport {
    sealed interface Phase {
        data object Idle : Phase
        data object Importing : Phase
        data object SeekingCovers : Phase
        data object Finished : Phase
        data class Failed(val message: String) : Phase
    }

    var phase by mutableStateOf<Phase>(Phase.Idle)
        private set
    var outcome by mutableStateOf<GoodreadsImportOutcome?>(null)
        private set
    var coversRemaining by mutableIntStateOf(0)
        private set
    var coversFound by mutableIntStateOf(0)
        private set

    val isRunning: Boolean get() = phase == Phase.Importing || phase == Phase.SeekingCovers

    /** How far it has got, books written then covers sought, from 0 to 1. */
    val progress: Float
        get() {
            val outcome = outcome ?: return if (phase == Phase.Finished) 1f else 0f
            val total = maxOf(outcome.pendingCovers, 1)
            return 0.3f + 0.7f * (total - coversRemaining) / total
        }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    /** Writes the ticked rows, then seeks their covers. Ignored while one runs. */
    fun start(csv: String, choices: GoodreadsChoices) {
        if (isRunning) return
        phase = Phase.Importing
        outcome = null
        coversFound = 0
        scope.launch {
            try {
                val written = GoodreadsApi.importExport(csv, choices)
                outcome = written
                coversRemaining = written.pendingCovers
                phase = Phase.SeekingCovers
                while (coversRemaining > 0) {
                    val (found, remaining) = try {
                        GoodreadsApi.seekCovers()
                    } catch (error: Exception) {
                        reportError(error)
                        break
                    }
                    coversFound += found
                    coversRemaining = remaining
                }
                phase = Phase.Finished
            } catch (error: Exception) {
                phase = Phase.Failed(reportError(error))
            }
        }
    }

    /** Back to idle once the reader has seen how it ended. */
    fun reset() {
        if (isRunning) return
        phase = Phase.Idle
        outcome = null
    }
}
