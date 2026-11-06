package com.polyforms.shiori.shared

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import com.google.firebase.FirebaseApp
import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import com.polyforms.shiori.MainActivity
import com.polyforms.shiori.R
import com.polyforms.shiori.features.settings.NotificationsApi
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await

/** Whether the reader lets Shiori notify: still to ask, allowed, refused. */
enum class NotificationAuthorization { NOT_DETERMINED, AUTHORIZED, DENIED }

/**
 * The phone's side of the release alerts: the permission, the FCM token handed to the server,
 * forgotten at sign-out. The permission is asked through [requester], which the activity sets.
 */
object PushRegistrar {
    const val CHANNEL = "alerts"
    private var currentToken: String? = null
    private var asked = false

    /** The answer the permission prompt owes. */
    var pendingAnswer: kotlinx.coroutines.CompletableDeferred<Boolean>? = null

    /** Asks Android for the permission; set by the screen that can show the prompt. */
    var requester: (suspend () -> Boolean)? = null

    /** A tap on an alert: Découvrir opens. */
    val openDiscover = MutableSharedFlow<Unit>(extraBufferCapacity = 1)

    private val context: Context get() = AppContext.get()
    private val isReady: Boolean get() = FirebaseApp.getApps(context).isNotEmpty()

    fun authorization(): NotificationAuthorization {
        val enabled = NotificationManagerCompat.from(context).areNotificationsEnabled()
        if (Build.VERSION.SDK_INT < 33) return if (enabled) NotificationAuthorization.AUTHORIZED else NotificationAuthorization.DENIED
        val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        return when {
            granted && enabled -> NotificationAuthorization.AUTHORIZED
            asked || !enabled -> NotificationAuthorization.DENIED
            else -> NotificationAuthorization.NOT_DETERMINED
        }
    }

    suspend fun requestPermission(): Boolean {
        if (Showcase.isOn) return true
        val granted = when (authorization()) {
            NotificationAuthorization.AUTHORIZED -> true
            NotificationAuthorization.DENIED -> false
            NotificationAuthorization.NOT_DETERMINED -> (requester?.invoke() ?: false).also { asked = true }
        }
        if (granted) refreshRegistration()
        return granted
    }

    suspend fun refreshRegistration() {
        if (!isReady || authorization() != NotificationAuthorization.AUTHORIZED) return
        try {
            register(FirebaseMessaging.getInstance().token.await())
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun register(token: String) {
        currentToken = token
        try {
            NotificationsApi.registerDevice(token)
        } catch (error: Exception) {
            reportError(error)
        }
    }

    suspend fun forgetDevice() {
        val token = currentToken ?: return
        currentToken = null
        runCatching { NotificationsApi.unregisterDevice(token) }
    }

    fun createChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(NotificationChannel(CHANNEL, L("Alertes"), NotificationManager.IMPORTANCE_DEFAULT))
    }
}

/** FCM's entry: a new token goes to the server, an alert is shown in the alerts channel. */
class ShioriMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        AppScope.launch { PushRegistrar.register(token) }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        val notification = message.notification ?: return
        val open = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).putExtra(MainActivity.OPEN_DISCOVER, true).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val shown = NotificationCompat.Builder(this, PushRegistrar.CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(notification.title)
            .setContentText(notification.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notification.body))
            .setAutoCancel(true)
            .setContentIntent(open)
            .build()
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED || Build.VERSION.SDK_INT < 33) {
            NotificationManagerCompat.from(this).notify(message.messageId.hashCode(), shown)
        }
    }
}
