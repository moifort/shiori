package com.polyforms.shiori.shared

import android.content.Context
import android.os.Bundle
import com.google.firebase.FirebaseApp
import com.google.firebase.analytics.FirebaseAnalytics
import com.polyforms.shiori.BuildConfig
import io.sentry.Sentry
import io.sentry.protocol.Feedback
import kotlinx.coroutines.CancellationException
import java.io.IOException
import java.net.SocketTimeoutException
import java.net.UnknownHostException

/**
 * Reports an error to Sentry, unless it is a cancellation, a lost connection or the AI being out
 * of credit, and returns the message a screen shows.
 */
fun reportError(error: Throwable): String {
    val ignored = isCancellation(error) || isConnectivityLoss(error) ||
        (error as? ApiError)?.domainCode == "AI_UNAVAILABLE"
    if (!ignored && Sentry.isEnabled()) Sentry.captureException(error)
    return error.localizedMessage ?: L("Une erreur est survenue")
}

fun isCancellation(error: Throwable): Boolean = error is CancellationException

private fun isConnectivityLoss(error: Throwable): Boolean {
    var current: Throwable? = error
    while (current != null) {
        if (current is UnknownHostException || current is SocketTimeoutException || current is java.net.ConnectException) return true
        if (current is IOException && current.message?.contains("connection", ignoreCase = true) == true) return true
        current = current.cause
    }
    return false
}

enum class FeedbackKind { BUG, IDEA }

/** A reader's bug report or idea, sent to Sentry's user feedback, tagged with its kind. */
fun sendFeedback(kind: FeedbackKind, message: String) {
    if (!Sentry.isEnabled()) return
    Sentry.configureScope { it.setTag("feedback.kind", kind.name.lowercase()) }
    Sentry.captureFeedback(Feedback(message))
    Sentry.configureScope { it.removeTag("feedback.kind") }
}

/** The product events the funnel is read from, named as on iOS so both apps feed one report. */
sealed class AnalyticsEvent(val name: String, val parameters: Map<String, Any>? = null) {
    data object OnboardingStarted : AnalyticsEvent("onboarding_started")
    data object OnboardingCompleted : AnalyticsEvent("onboarding_completed")
    class BookAdded(source: BookSource) : AnalyticsEvent("book_added", mapOf("source" to source.value))
    data object ScanStarted : AnalyticsEvent("scan_started")
    data object ScanSucceeded : AnalyticsEvent("scan_succeeded")
    data object ScanNoResult : AnalyticsEvent("scan_no_result")
    data object ScanFailed : AnalyticsEvent("scan_failed")
    data object ScanBlockedByQuota : AnalyticsEvent("scan_blocked_quota")
    class ShelfDetected(books: Int) : AnalyticsEvent("shelf_detected", mapOf("books" to books))
    class LibraryStocked(books: Int) : AnalyticsEvent("library_stocked", mapOf("books" to books))
    class BookRated(stars: Double) : AnalyticsEvent("book_rated", mapOf("stars" to stars))
    data object SeriesCatalogued : AnalyticsEvent("series_catalogued")
    class PaywallShown(trigger: String) : AnalyticsEvent("paywall_shown", mapOf("trigger" to trigger))
    class PurchaseCompleted(plan: String) : AnalyticsEvent("purchase_completed", mapOf("plan" to plan))

    enum class BookSource(val value: String) { SCAN("scan"), MANUAL("manual"), SERIES("series"), DISCOVER("discover"), AUTHOR("author"), SHELF("shelf") }
}

object Analytics {
    /** Debug builds send nothing unless asked: their taps are not readers'. */
    private val enabled: Boolean get() = !BuildConfig.DEBUG && FirebaseApp.getApps(AppContext.get()).isNotEmpty()

    fun start(context: Context) {
        if (FirebaseApp.getApps(context).isEmpty()) return
        FirebaseAnalytics.getInstance(context).setAnalyticsCollectionEnabled(!BuildConfig.DEBUG)
    }

    fun track(event: AnalyticsEvent) {
        if (!enabled) return
        val bundle = Bundle()
        event.parameters?.forEach { (key, value) ->
            when (value) {
                is Int -> bundle.putLong(key, value.toLong())
                is Double -> bundle.putDouble(key, value)
                else -> bundle.putString(key, value.toString())
            }
        }
        FirebaseAnalytics.getInstance(AppContext.get()).logEvent(event.name, bundle)
    }

    /** An event sent once per install, ever. */
    fun trackOnce(event: AnalyticsEvent) {
        val prefs = AppContext.get().getSharedPreferences("analytics", Context.MODE_PRIVATE)
        val key = "once.${event.name}"
        if (prefs.getBoolean(key, false)) return
        prefs.edit().putBoolean(key, true).apply()
        track(event)
    }
}

fun track(event: AnalyticsEvent) = Analytics.track(event)
