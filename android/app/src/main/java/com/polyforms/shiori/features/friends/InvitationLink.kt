package com.polyforms.shiori.features.friends

import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/**
 * The shape of an invitation link, on both sides of the tap.
 *
 * A link rather than a bare code, because a link is what people send each other — and an App Link
 * rather than an ordinary one, so that on a phone with Shiori installed the tap opens the app on
 * the invitation instead of a web page. Three things have to agree for that: the `autoVerify`
 * intent filter in the manifest, the `assetlinks.json` the server publishes at that same host, and
 * the host below. When they disagree the link simply opens the browser again.
 */
object InvitationLink {
    /** The API's own host, which serves both the invitation page and the association file. */
    const val HOST = "shiori-server-hvrhl6ox5q-ey.a.run.app"

    /** The scheme the invitation page's "Ouvrir dans Shiori" button uses. */
    const val SCHEME = "shiori"
    private const val PATH = "invite"

    /** The link to send: the app when Shiori is installed, the web page when it is not. */
    fun url(code: String) = "https://$HOST/$PATH/$code"

    /**
     * The invitation code a tapped link carries, or null when the URL is something else. Both forms
     * are read: the App Link, and `shiori://invite/<CODE>`. Upper-cased, since a link typed by hand
     * or lowered by a mail client still names the same invitation.
     */
    fun code(url: Uri): String? {
        val segments = url.pathSegments
        if (url.scheme == SCHEME) {
            if (url.host != PATH) return null
            return segments.firstOrNull()?.let(::normalized)
        }
        if (url.host != HOST || segments.size != 2 || segments[0] != PATH) return null
        return normalized(segments[1])
    }

    /** The code of a pasted text, a link copied by the invitation page. */
    fun code(text: String): String? = runCatching { Uri.parse(text.trim()) }.getOrNull()?.let(::code)

    /** Eight letters or digits and nothing else: a stray path is not an invitation. */
    fun normalized(code: String): String? {
        val upper = code.uppercase()
        return if (upper.length == 8 && upper.all { it.isLetterOrDigit() }) upper else null
    }
}

/** An invitation the reader arrived on by tapping a link, waiting to be taken up. */
data class InvitationRequest(val code: String)

/**
 * The invitation a new reader brought from Google Play. A link opened before Shiori was installed
 * does not survive the store by itself; on Android the store carries it: the invitation page sends
 * the phone to Play with `referrer=invite=<CODE>`, and Play hands that referrer to the app's first
 * opening. iOS has nothing like it, which is why its page copies the link for the reader to paste.
 */
object InstallInvitation {
    private const val KEY = "invite"

    /** The code the install referrer carries, read once; null when Play has none, or never answers. */
    suspend fun code(context: Context): String? = withTimeoutOrNull(5_000) {
        suspendCancellableCoroutine { continuation ->
            val client = InstallReferrerClient.newBuilder(context.applicationContext).build()
            continuation.invokeOnCancellation { runCatching { client.endConnection() } }
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    val referrer = if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                        runCatching { client.installReferrer.installReferrer }.getOrNull()
                    } else {
                        null
                    }
                    runCatching { client.endConnection() }
                    if (continuation.isActive) continuation.resume(referrer?.let(::codeOfReferrer))
                }

                override fun onInstallReferrerServiceDisconnected() {
                    if (continuation.isActive) continuation.resume(null)
                }
            })
        }
    }

    /** `invite=AB12CD34`, alone or among other parameters (`utm_source=…&invite=…`). */
    fun codeOfReferrer(referrer: String): String? =
        referrer.split('&').firstNotNullOfOrNull { pair ->
            val (name, value) = pair.split('=', limit = 2).let { it[0] to it.getOrNull(1) }
            if (name == KEY) value?.let { InvitationLink.normalized(java.net.URLDecoder.decode(it, "UTF-8")) } else null
        }
}

/**
 * Whether the first opening should offer to paste an invitation: only for a reader who has just
 * been through onboarding — a new install — whom Play brought no invitation, and only when the
 * clipboard holds text, which its description tells without reading it (no "pasted" toast).
 */
object PastedInvitation {
    private const val PREFERENCES = "invitations"

    /** Set as onboarding completes, cleared once asked. */
    private const val PENDING = "pastedInvitationPending"

    fun markPending(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE).edit().putBoolean(PENDING, true).apply()

    /** True once, the first time it is asked after onboarding. */
    fun takePending(context: Context): Boolean {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val pending = preferences.getBoolean(PENDING, false)
        if (pending) preferences.edit().putBoolean(PENDING, false).apply()
        return pending
    }

    fun clipboardHoldsText(context: Context): Boolean {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return false
        return clipboard.primaryClipDescription?.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN) == true
    }

    /** What the Coller button hands over: read only when the reader presses it. */
    fun pastedText(context: Context): String? {
        val clipboard = context.getSystemService(ClipboardManager::class.java) ?: return null
        return clipboard.primaryClip?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.coerceToText(context)?.toString()
    }
}
