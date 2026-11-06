package com.polyforms.shiori.features.scan

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.features.book.BookCorrection
import com.polyforms.shiori.features.book.BookDraft
import com.polyforms.shiori.features.book.BookVocabulary
import com.polyforms.shiori.features.book.Change
import com.polyforms.shiori.features.book.SeriesPlacement
import com.polyforms.shiori.features.discover.ReleaseFormat
import com.polyforms.shiori.shared.AnalyticsEvent
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.BookFormat
import com.polyforms.shiori.shared.BookLanguage
import com.polyforms.shiori.shared.reportError
import com.polyforms.shiori.shared.track

/** A scan: the photo or text, the AI's reading, the review, the book added. */
class ScanViewModel(private val client: ScanClient) {
    enum class Step { CAMERA, ANALYZING, REVIEW, NO_RESULT, FAILED }

    var step by mutableStateOf(Step.CAMERA)
        private set
    var capturedCover by mutableStateOf<ByteArray?>(null)
        private set
    var draft by mutableStateOf<BookDraft?>(null)
        private set
    var ownedCopy by mutableStateOf<Book?>(null)
        private set
    var failure by mutableStateOf<String?>(null)
        private set
    var error by mutableStateOf<String?>(null)
    var paywallShown by mutableStateOf(false)
    var isSaving by mutableStateOf(false)
        private set
    var awaitable by mutableStateOf<List<ReleaseFormat>>(emptyList())
        private set
    private var typedTitle: String? = null
    private var sharedLink: String? = null

    private suspend fun read(source: suspend () -> ScannedBook) {
        step = Step.ANALYZING
        track(AnalyticsEvent.ScanStarted)
        try {
            val scanned = source()
            if (!scanned.recognized || scanned.title.isNullOrEmpty()) {
                track(AnalyticsEvent.ScanNoResult)
                step = Step.NO_RESULT
                return
            }
            track(AnalyticsEvent.ScanSucceeded)
            draft = scanned.asDraft
            ownedCopy = scanned.ownedCopy
            step = Step.REVIEW
        } catch (failed: ApiError) {
            if (failed.domainCode == "QUOTA_EXHAUSTED") {
                track(AnalyticsEvent.ScanBlockedByQuota)
                step = Step.CAMERA
                paywallShown = true
            } else {
                fail(failed)
            }
        } catch (failed: Exception) {
            fail(failed)
        }
    }

    private fun fail(failed: Exception) {
        track(AnalyticsEvent.ScanFailed)
        failure = reportError(failed)
        step = Step.FAILED
    }

    suspend fun capture(jpeg: ByteArray) {
        capturedCover = jpeg
        read { client.scan(jpeg) }
    }

    suspend fun lookUp(link: String) {
        capturedCover = null
        typedTitle = null
        sharedLink = link
        read { client.lookUpLink(link) }
    }

    suspend fun lookUpTitle(title: String) {
        capturedCover = null
        typedTitle = title
        read { client.lookUpTitle(title) }
    }

    suspend fun retry() {
        failure = null
        val jpeg = capturedCover
        val title = typedTitle
        val link = sharedLink
        when {
            jpeg != null -> capture(jpeg)
            title != null -> lookUpTitle(title)
            link != null -> lookUp(link)
            else -> step = Step.CAMERA
        }
    }

    suspend fun save(draft: BookDraft, placement: SeriesPlacement?): Book? {
        isSaving = true
        try {
            var book = client.add(if (placement != null) draft.copy(series = null) else draft)
            track(AnalyticsEvent.BookAdded(AnalyticsEvent.BookSource.SCAN))
            if (placement != null) {
                try {
                    book = client.update(book.id, BookCorrection(series = Change.Set(placement)))
                } catch (failed: Exception) {
                    reportError(failed)
                }
            }
            if (draft.rating > 0 || draft.favorite) {
                try {
                    if (draft.rating > 0) book = client.rate(book.id, draft.rating)
                    if (draft.favorite) book = client.setFavorite(book.id, true)
                } catch (failed: Exception) {
                    reportError(failed)
                }
            }
            return book
        } catch (failed: Exception) {
            error = reportError(failed)
            return null
        } finally {
            isSaving = false
        }
    }

    suspend fun wish(draft: BookDraft): Boolean {
        isSaving = true
        return try {
            client.wish(draft)
            true
        } catch (failed: Exception) {
            error = reportError(failed)
            false
        } finally {
            isSaving = false
        }
    }

    suspend fun loadAwaitable(language: BookLanguage?, format: BookFormat) {
        if (language == null) {
            awaitable = emptyList()
            return
        }
        try {
            awaitable = client.awaitableFormats(language, format)
        } catch (failed: Exception) {
            reportError(failed)
        }
    }

    suspend fun vocabulary(): BookVocabulary? = runCatching { client.vocabulary() }.getOrNull()

    suspend fun subgenres(): List<String> = runCatching { client.subgenres() }.getOrDefault(emptyList())

    fun retake() {
        capturedCover = null
        typedTitle = null
        sharedLink = null
        failure = null
        draft = null
        ownedCopy = null
        step = Step.CAMERA
    }
}
