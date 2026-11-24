package com.polyforms.shiori.features.listening

import android.app.PendingIntent
import android.content.Intent
import androidx.media3.session.MediaSession
import androidx.media3.session.MediaSessionService
import com.polyforms.shiori.MainActivity

/**
 * Android's counterpart of iOS's `audio` background mode and Now Playing: the media session of
 * the app's one [AudiblePlayer], held by a foreground service while a title plays. The system
 * draws its notification and lock screen controls from it, a headset's buttons reach it, and the
 * listening goes on with the app behind.
 */
class PlaybackService : MediaSessionService() {
    private var session: MediaSession? = null

    override fun onCreate() {
        super.onCreate()
        val opensApp = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        session = MediaSession.Builder(this, AudiblePlayers.app(this).sessionPlayer)
            .setSessionActivity(opensApp)
            .build()
    }

    override fun onGetSession(controllerInfo: MediaSession.ControllerInfo): MediaSession? = session

    override fun onDestroy() {
        // The session only: the player is the app's, and outlives the service.
        session?.release()
        session = null
        super.onDestroy()
    }
}
