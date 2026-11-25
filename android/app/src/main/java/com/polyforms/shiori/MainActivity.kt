package com.polyforms.shiori

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import com.polyforms.shiori.features.friends.InvitationLink
import com.polyforms.shiori.shared.PushRegistrar
import kotlinx.coroutines.flow.MutableSharedFlow
import com.polyforms.shiori.shared.Showcase
import com.polyforms.shiori.shared.components.styles.ShioriTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // The captures draw the App Store fixtures alone, without a session.
        if (BuildConfig.DEBUG && intent.getBooleanExtra("showcase", false)) Showcase.isOn = true
        val preview = if (BuildConfig.DEBUG) intent.getStringExtra("preview") else null
        route(intent)
        setContent {
            ShioriTheme {
                if (preview != null) DebugPreviews(preview) else ShioriRoot()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        route(intent)
    }

    /** A tapped alert opens the News tab, as on iOS; an invitation link asks before it is
     *  taken up. An alert reaches here two ways: shown by [ShioriMessagingService] while the app
     *  is open, with [OPEN_NEWS], or shown by the system while it is closed, which hands the
     *  activity FCM's own extras. */
    private fun route(intent: Intent) {
        if (PushRegistrar.isTappedAlert(intent)) PushRegistrar.openNews.tryEmit(Unit)
        intent.data?.let(InvitationLink::code)?.let { invitations.tryEmit(it) }
        if (intent.type in CSV_TYPES) {
            val file = if (intent.action == Intent.ACTION_VIEW) {
                intent.data
            } else if (android.os.Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
            } else {
                @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            file?.let { goodreadsFiles.tryEmit(it) }
            return
        }
        if (intent.action == Intent.ACTION_SEND) {
            val image = if (android.os.Build.VERSION.SDK_INT >= 33) {
                intent.getParcelableExtra(Intent.EXTRA_STREAM, android.net.Uri::class.java)
            } else {
                @Suppress("DEPRECATION") intent.getParcelableExtra(Intent.EXTRA_STREAM)
            }
            val link = intent.getStringExtra(Intent.EXTRA_TEXT)?.let { Regex("https?://\\S+").find(it)?.value }
            when {
                image != null -> shared.tryEmit(SharedIntake.Image(image))
                link != null -> shared.tryEmit(SharedIntake.Link(link))
            }
        }
    }

    companion object {
        const val OPEN_NEWS = "openNews"

        private val CSV_TYPES = setOf("text/csv", "text/comma-separated-values")

        /** A Goodreads export opened in Shiori, kept until the signed-in app imports it. */
        val goodreadsFiles = MutableSharedFlow<android.net.Uri>(replay = 1, extraBufferCapacity = 1)

        /** Invitation codes from tapped links, kept until the signed-in app takes them. */
        val invitations = MutableSharedFlow<String>(replay = 1, extraBufferCapacity = 1)

        /** What another app shared to Shiori, kept until the signed-in app scans it. */
        val shared = MutableSharedFlow<SharedIntake>(replay = 1, extraBufferCapacity = 1)
    }
}

/** A page or a photo shared from another app, opened on the scan. */
sealed interface SharedIntake {
    data class Link(val url: String) : SharedIntake
    data class Image(val uri: android.net.Uri) : SharedIntake
}
