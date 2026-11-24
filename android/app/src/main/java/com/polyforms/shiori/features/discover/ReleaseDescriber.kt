package com.polyforms.shiori.features.discover

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * Asks the server to describe a release when its page opens, and keeps the release it answers for
 * the page to draw: the same record its list showed, completed. A release described already is not
 * asked again. A page that could not have it described — the allowance used up, or the model
 * failing — stays the release it opened as.
 */
class ReleaseDescriber(release: Release, private val describeRelease: suspend () -> Release) {
    /** The release as the page draws it: the list's, then the server's answer. */
    var release by mutableStateOf(release)
        private set

    /**
     * The AI is writing the description, and has been for long enough to be worth saying: a page
     * answered from the server's cache in a blink never shows it.
     */
    var isDescribing by mutableStateOf(false)
        private set
    private var inFlight = false

    suspend fun describe() {
        if (release.described || inFlight) return
        inFlight = true
        coroutineScope {
            val announce = launch {
                delay(GRACE_MILLIS)
                isDescribing = true
            }
            try {
                release = describeRelease()
            } catch (error: Throwable) {
                if (!isCancellation(error) && (error as? ApiError)?.domainCode != "QUOTA_EXHAUSTED") reportError(error)
            } finally {
                announce.cancel()
                inFlight = false
                isDescribing = false
            }
        }
    }

    /** The cover a reader picked for it, as the server answered it: drawn at once. */
    fun drawCover(url: String) {
        release = release.copy(coverURL = url)
    }

    private companion object {
        /** How long a call may run before the AI is said to be at work: a cached answer is back well within it. */
        const val GRACE_MILLIS = 400L
    }
}
