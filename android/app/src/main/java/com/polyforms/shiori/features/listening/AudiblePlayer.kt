// This file is the app's Media3 integration: a forwarding player for the session and Widevine
// DRM, both marked unstable by Media3, so the whole file opts in.
@file:OptIn(UnstableApi::class)

package com.polyforms.shiori.features.listening

import android.content.ComponentName
import androidx.annotation.OptIn
import androidx.media3.common.util.UnstableApi
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.ConnectivityManager
import android.net.Network
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import androidx.lifecycle.ProcessLifecycleOwner
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.ForwardingPlayer
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import androidx.media3.common.MimeTypes
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.drm.DefaultDrmSessionManager
import androidx.media3.exoplayer.drm.ExoMediaDrm
import androidx.media3.exoplayer.drm.FrameworkMediaDrm
import androidx.media3.exoplayer.drm.HttpMediaDrmCallback
import androidx.media3.exoplayer.drm.MediaDrmCallback
import androidx.media3.exoplayer.source.DefaultMediaSourceFactory
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.polyforms.shiori.shared.ApiError
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.isCancellation
import com.polyforms.shiori.shared.reportError
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import java.io.IOException
import java.time.Duration
import java.time.Instant
import java.util.UUID
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sqrt

/**
 * The Audible player: one title at a time, for the whole app.
 *
 * It plays the Widevine stream the server's licence names with Media3, as it is — the key is
 * asked through the server, which keeps the device credentials, and nothing is ever decrypted
 * outside Android's own DRM. It keeps playing with the screen locked, answers the notification,
 * the lock screen and a headset (its media session, held by [PlaybackService]), resumes where the
 * reader stopped on any Audible player, and saves the position back to Audible while it plays.
 *
 * A cut shows as a wait for the network, which takes the listening up again by itself, and a
 * position saved offline waits on the phone until Audible can have it.
 *
 * Created once for the app ([AudiblePlayers]) and handed down through [LocalAudiblePlayer]; no
 * view reads a shared instance.
 */
class AudiblePlayer(
    context: Context?,
    private val client: ListeningClient = ListeningClient.live,
    restoresLastTitle: Boolean = false,
    store: KeyValueStore = context?.let { KeyValueStore.Preferences(it) } ?: KeyValueStore.InMemory(),
) {
    sealed interface Phase {
        /** The licence is being asked for, or the stream is buffering its start. */
        data object Loading : Phase
        data object Ready : Phase

        /**
         * No network, and nothing on the phone to play from here: the listening starts again by
         * itself once the network is back.
         */
        data object Waiting : Phase

        /** Amazon refused or the stream failed: the message says which. */
        data class Failed(val message: String) : Phase
    }

    /** What is being listened to. Null when nothing is: the accessory is gone. */
    var title by mutableStateOf<ListeningTitle?>(null)
        private set
    var phase by mutableStateOf<Phase>(Phase.Loading)
        private set
    var isPlaying by mutableStateOf(false)
        private set
    var elapsed by mutableStateOf(0.0)
        private set
    var duration by mutableStateOf(0.0)
        private set
    var chapters by mutableStateOf<List<ListeningChapter>>(emptyList())
        private set

    /** When the sleep timer pauses the player, and what it was set to. */
    var sleepTimer by mutableStateOf<SleepTimer?>(null)
        private set

    val progress: ListeningProgress get() = ListeningProgress(elapsed, duration, chapters)

    private val context = context?.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val positions = ListeningPositions(store)
    private val lastTitle = LastListenedTitle(store)
    private var isOnline = true

    /** Whether the listening takes up again once the network is back: a tap while it waits says no. */
    private var resumesOnReconnect = true
    private var playback: Playback? = null
    private var lastSaved: Double? = null
    private var lastSaveAt = Instant.EPOCH
    private var sleepJob: Job? = null

    /**
     * The timer's last choice and when it paused the player: a headset press or a shake soon
     * after takes the listening up for as long again.
     */
    private var lastSleepMinutes: Int? = null
    private var sleptAt: Instant? = null
    private var startJob: Job? = null
    private var seekSaveJob: Job? = null

    /**
     * The stream once played: a failure after that is an expired signed link rather than a
     * refusal, and asking for a fresh licence fixes it once.
     */
    private var hasPlayed = false
    private var hasRetried = false
    private var controller: ListenableFuture<MediaController>? = null

    /** Media3's player, built the first time a title is opened: a preview never needs one. */
    private val exo: ExoPlayer by lazy { buildPlayer() }
    private var exoBuilt = false

    init {
        if (this.context != null) {
            observeNetwork()
            observeApp()
            if (restoresLastTitle) lastTitle.value?.let(::prepare)
        }
    }

    /**
     * The title back, paused where it stopped: its licence is asked as for a play, but nothing
     * starts until the reader asks.
     */
    private fun prepare(title: ListeningTitle) {
        this.title = title
        phase = Phase.Loading
        resumesOnReconnect = false
        start(null)
    }

    // Commands

    /**
     * Play a title, from where the reader stopped on any Audible player. The accessory shows it
     * at once, with a loader, while the licence is asked.
     */
    fun play(title: ListeningTitle, fromStart: Boolean = false) {
        if (title.asin == this.title?.asin && phase == Phase.Ready) {
            if (fromStart) seek(0.0)
            resume()
            return
        }
        saveNow()
        teardownStream()
        this.title = title
        lastTitle.value = title
        phase = Phase.Loading
        elapsed = 0.0
        duration = 0.0
        chapters = emptyList()
        hasPlayed = false
        hasRetried = false
        resumesOnReconnect = true
        lastSaved = null
        start(if (fromStart) 0.0 else null)
    }

    fun togglePlayPause() {
        if (phase == Phase.Waiting) {
            resumesOnReconnect = !resumesOnReconnect
            isPlaying = resumesOnReconnect
            return
        }
        val title = title
        if (phase is Phase.Failed && title != null) {
            this.title = null
            play(title)
            return
        }
        if (isPlaying) pause() else resume()
    }

    fun resume() {
        if (phase != Phase.Ready) return
        resumesOnReconnect = true
        exo.play()
    }

    fun pause() {
        if (exoBuilt) exo.pause()
        saveNow()
    }

    fun skip(seconds: Double) = seek(elapsed + seconds)

    fun previousChapter() = seek(progress.previousChapterStart)

    fun nextChapter() {
        progress.nextChapterStart?.let(::seek)
    }

    /**
     * Move to a position. The bar slides there at once, and Audible hears of it once the taps
     * have settled, not once per tap.
     */
    fun seek(seconds: Double) {
        if (phase != Phase.Ready) return
        val target = min(max(0.0, seconds), max(0.0, duration - 1))
        elapsed = target
        if (exoBuilt) exo.seekTo((target * 1000).toLong())
        seekSaveJob?.cancel()
        seekSaveJob = scope.launch {
            delay((SEEK_SAVE_DELAY * 1000).toLong())
            saveNow()
        }
    }

    /**
     * What follows the title playing, in the order the player will take it: the queue the
     * full-screen player lists.
     */
    suspend fun upNext(): List<ListeningQueueEntry> = title?.asin?.let { client.queue(it) } ?: emptyList()

    /** Pause in `minutes`, or turn the timer off when that choice is the one set. */
    fun toggleSleepTimer(minutes: Int) {
        sleepJob?.cancel()
        if (sleepTimer?.minutes == minutes) {
            sleepTimer = null
            lastSleepMinutes = null
            setVolume(1f)
            return
        }
        startSleepTimer(minutes)
    }

    private fun startSleepTimer(minutes: Int) {
        sleepJob?.cancel()
        setVolume(1f)
        lastSleepMinutes = minutes
        sleptAt = null
        val timer = SleepTimer.starting(minutes, Instant.now())
        sleepTimer = timer
        listenForShakes()
        sleepJob = scope.launch {
            // Full volume until the fade, then down to silence in small steps, and the pause
            // once it is reached. It runs with the screen locked too: the service keeps the
            // app alive while it plays.
            delay(max(0, Duration.between(Instant.now(), timer.fadeStartsAt).toMillis()))
            while (isActive && !timer.isOver(Instant.now())) {
                setVolume(timer.volume(Instant.now()))
                delay(FADE_STEP_MS)
            }
            sleepTimer = null
            sleptAt = Instant.now()
            pause()
            // The next listening starts at its usual volume.
            setVolume(1f)
        }
    }

    /** Whether the sleep timer is fading the listening out right now. */
    val isSleepFading: Boolean get() = sleepTimer?.isFading(Instant.now()) ?: false

    /**
     * A headset press or a shake: the timer starts over for as long as it was set, at full
     * volume again, and a listening it just paused plays again. Answers whether it did anything.
     */
    fun restartSleepTimer(): Boolean {
        sleepTimer?.let {
            startSleepTimer(it.minutes)
            return true
        }
        val minutes = lastSleepMinutes
        val sleptAt = sleptAt
        if (minutes != null && sleptAt != null && Duration.between(sleptAt, Instant.now()).seconds < SLEEP_RESTART_WINDOW) {
            startSleepTimer(minutes)
            resume()
            return true
        }
        return false
    }

    /** Stop listening: the position is saved and the accessory goes. */
    fun stop() {
        saveNow()
        sleepJob?.cancel()
        sleepTimer = null
        setVolume(1f)
        teardownStream()
        title = null
        lastTitle.value = null
        playback = null
        isPlaying = false
        stopListeningForShakes()
        controller?.let(MediaController::releaseFuture)
        controller = null
    }

    /**
     * Shows a title as if it were playing, with no stream behind it: for previews and captures,
     * where Widevine cannot run.
     */
    fun showPreview(title: ListeningTitle, playback: Playback, playing: Boolean = true) {
        this.title = title
        this.playback = playback
        phase = Phase.Ready
        duration = playback.duration
        chapters = playback.chapters
        elapsed = playback.resumeAt ?: 0.0
        isPlaying = playing
    }

    // Stream

    private fun start(position: Double?) {
        val title = title ?: return
        startJob?.cancel()
        startJob = scope.launch {
            try {
                val playback = client.start(title.asin)
                if (this@AudiblePlayer.title?.asin != title.asin) return@launch
                val resume = ListeningPositions.resume(playback.resumeAt, playback.resumeSavedAt, positions.entry(title.asin))
                open(playback, position ?: resume ?: 0.0)
            } catch (error: Throwable) {
                if (isCancellation(error)) throw error
                if (isConnectivityLoss(error) || !isOnline) {
                    waitForNetwork(position ?: positions.entry(title.asin)?.position)
                    return@launch
                }
                phase = Phase.Failed(message(error))
                reportError(error)
            }
        }
    }

    /**
     * No stream and no network: the title stays, its position too, and the listening starts
     * again by itself once the network is back.
     */
    private fun waitForNetwork(position: Double?) {
        val wasPlaying = isPlaying || phase == Phase.Loading
        teardownStream()
        position?.let { elapsed = it }
        phase = Phase.Waiting
        resumesOnReconnect = wasPlaying && resumesOnReconnect
        isPlaying = resumesOnReconnect
    }

    private fun open(playback: Playback, position: Double) {
        val context = context ?: return
        val title = title ?: return
        this.playback = playback
        duration = playback.duration
        chapters = playback.chapters
        elapsed = position
        lastSaved = position

        val item = MediaItem.Builder()
            .setMediaId(playback.asin)
            .setUri(playback.streamURL)
            .setMimeType(MimeTypes.APPLICATION_MPD)
            .setDrmConfiguration(MediaItem.DrmConfiguration.Builder(C.WIDEVINE_UUID).build())
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(title.title)
                    .setArtist(title.subtitle)
                    .setArtworkUri(title.coverURL?.let(android.net.Uri::parse))
                    .setMediaType(MediaMetadata.MEDIA_TYPE_AUDIO_BOOK)
                    .build(),
            )
            .build()
        exo.setMediaItem(item, (position * 1000).toLong())
        exo.playWhenReady = resumesOnReconnect
        exo.prepare()
        // The session's service: the notification, the lock screen and a headset, and what
        // keeps the listening going once the app is behind.
        if (controller == null) {
            controller = MediaController.Builder(context, SessionToken(context, ComponentName(context, PlaybackService::class.java)))
                .buildAsync()
        }
    }

    /**
     * The book is over: its end is saved on Audible — the nightly sync then files it as read —
     * and the audiobook started most recently among those under way follows, as the next episode
     * does.
     */
    private fun finished() {
        val playback = playback ?: return
        elapsed = duration
        saveNow()
        scope.launch {
            val next = runCatching { client.queue(playback.asin).firstOrNull()?.title }.getOrNull()
            if (this@AudiblePlayer.playback?.asin == playback.asin && next != null) play(next)
        }
    }

    private fun buildPlayer(): ExoPlayer {
        val context = checkNotNull(context)
        val drm = DefaultDrmSessionManager.Builder()
            .setUuidAndExoMediaDrmProvider(C.WIDEVINE_UUID, FrameworkMediaDrm.DEFAULT_PROVIDER)
            .build(WidevineKeys(client) { playback?.asin })
        val player = ExoPlayer.Builder(context)
            .setMediaSourceFactory(DefaultMediaSourceFactory(context).setDrmSessionManagerProvider { drm })
            // Spoken word: the system ducks or pauses it as it does a podcast, and pulling the
            // headphones out pauses it.
            .setAudioAttributes(
                AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_SPEECH).build(),
                true,
            )
            .setHandleAudioBecomingNoisy(true)
            .setWakeMode(C.WAKE_MODE_NETWORK)
            .setSeekBackIncrementMs((SKIP_INTERVAL * 1000).toLong())
            .setSeekForwardIncrementMs((SKIP_INTERVAL * 1000).toLong())
            .build()
        player.addListener(object : Player.Listener {
            override fun onPlaybackStateChanged(state: Int) {
                when (state) {
                    Player.STATE_READY -> if (phase != Phase.Ready) {
                        if (duration <= 0 && player.duration != C.TIME_UNSET) duration = player.duration / 1000.0
                        phase = Phase.Ready
                    }
                    Player.STATE_ENDED -> finished()
                    else -> Unit
                }
                playingChanged(player)
            }

            override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                // A call, another app, the headphones pulled out: the position follows.
                if (!playWhenReady && reason != Player.PLAY_WHEN_READY_CHANGE_REASON_USER_REQUEST) saveNow()
                playingChanged(player)
            }

            override fun onPlayerError(error: PlaybackException) = streamFailed(error)
        })
        scope.launch {
            while (isActive) {
                delay(TICK_MS)
                tick(player)
            }
        }
        exoBuilt = true
        return player
    }

    private fun playingChanged(player: Player) {
        if (phase == Phase.Waiting) return
        isPlaying = player.playWhenReady && player.playbackState in setOf(Player.STATE_BUFFERING, Player.STATE_READY)
    }

    private fun streamFailed(error: PlaybackException) {
        // The network went: wait for it rather than give up.
        if (!isOnline || isConnectivityLoss(error)) {
            waitForNetwork(elapsed)
            return
        }
        // The signed link expires: a stream that played once is asked again, from where it
        // stopped, before giving up.
        if (hasPlayed && !hasRetried) {
            hasRetried = true
            val position = elapsed
            teardownStream()
            phase = Phase.Loading
            start(position)
            return
        }
        isPlaying = false
        phase = Phase.Failed(L("Lecture impossible"))
        reportError(error)
    }

    private fun teardownStream() {
        startJob?.cancel()
        if (!exoBuilt) return
        exo.pause()
        exo.stop()
        exo.clearMediaItems()
    }

    private fun setVolume(volume: Float) {
        if (exoBuilt) exo.volume = volume
    }

    private fun message(error: Throwable): String = when ((error as? ApiError)?.domainCode) {
        "AUDIBLE_LICENSE_DENIED" -> L("Audible refuse la lecture")
        "AUDIBLE_NOT_CONNECTED" -> L("Compte Audible déconnecté")
        else -> L("Lecture impossible")
    }

    // Position

    /**
     * Save the position, if it moved since the last save: on the phone first, then on Audible.
     * One Audible cannot have yet waits on the phone and goes once the network is back.
     */
    private fun saveNow() {
        val playback = playback ?: return
        if (phase != Phase.Ready && phase != Phase.Waiting) return
        val position = elapsed
        lastSaved?.let { if (abs(it - position) < 1) return }
        lastSaved = position
        val savedAt = Instant.now()
        lastSaveAt = savedAt
        positions.record(playback.asin, position, playback.contentReference, savedAt)
        if (isOnline) send(playback.asin, playback.contentReference, position, savedAt)
    }

    private fun send(asin: String, contentReference: String, position: Double, savedAt: Instant) {
        scope.launch {
            try {
                client.savePosition(asin, contentReference, position)
                positions.markSent(asin, savedAt)
            } catch (error: Throwable) {
                if (isCancellation(error)) throw error
                reportError(error)
            }
        }
    }

    /** Every position saved with no network, now that there is one. */
    private fun sendPendingPositions() {
        positions.pending().forEach { (asin, entry) ->
            send(asin, entry.contentReference, entry.position, Instant.ofEpochMilli(entry.savedAt))
        }
    }

    private fun tick(player: Player) {
        if (phase != Phase.Ready || player.playbackState == Player.STATE_IDLE) return
        elapsed = player.currentPosition / 1000.0
        if (player.isPlaying) hasPlayed = true
        if (isPlaying && Duration.between(lastSaveAt, Instant.now()).seconds >= SAVE_INTERVAL) saveNow()
    }

    // Observation

    /**
     * The network, as the system sees it: its return sends the positions that waited and takes a
     * waiting listening up again.
     */
    private fun observeNetwork() {
        val manager = context?.getSystemService(ConnectivityManager::class.java) ?: return
        isOnline = manager.activeNetwork != null
        runCatching {
            manager.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    scope.launch { networkChanged(true) }
                }

                override fun onLost(network: Network) {
                    scope.launch { networkChanged(false) }
                }
            })
        }
    }

    private fun networkChanged(online: Boolean) {
        if (isOnline == online) return
        isOnline = online
        if (!online) return
        sendPendingPositions()
        if (phase == Phase.Waiting) {
            phase = Phase.Loading
            start(elapsed)
        }
    }

    private fun observeApp() {
        ProcessLifecycleOwner.get().lifecycle.addObserver(object : DefaultLifecycleObserver {
            override fun onStop(owner: LifecycleOwner) = saveNow()
            override fun onStart(owner: LifecycleOwner) {
                if (isOnline) sendPendingPositions()
            }
        })
    }

    // A shake, as in Audible's own app: the sleep timer starts over.

    private var shakes: SensorEventListener? = null

    private fun listenForShakes() {
        if (shakes != null) return
        val manager = context?.getSystemService(SensorManager::class.java) ?: return
        val sensor = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER) ?: return
        var lastShake = 0L
        val listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                val (x, y, z) = event.values
                val force = sqrt(x * x + y * y + z * z) / SensorManager.GRAVITY_EARTH
                val now = System.currentTimeMillis()
                if (force < SHAKE_FORCE || now - lastShake < 1000) return
                lastShake = now
                // Nothing left to restart: the phone is no longer listened to.
                if (!restartSleepTimer()) stopListeningForShakes()
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        shakes = listener
        manager.registerListener(listener, sensor, SensorManager.SENSOR_DELAY_UI)
    }

    private fun stopListeningForShakes() {
        shakes?.let { context?.getSystemService(SensorManager::class.java)?.unregisterListener(it) }
        shakes = null
    }

    // The media session

    /**
     * The player as the notification, the lock screen and a headset drive it: their commands go
     * through this player's own, so a position is saved and the sleep timer answers as it does
     * to a touch in the app. A headset's double and triple press are the chapters, as Audible
     * does.
     */
    val sessionPlayer: Player by lazy {
        object : ForwardingPlayer(exo) {
            override fun play() = playFromHeadset()

            // Some headsets send a pause rather than a toggle: while the timer fades the
            // listening out, it gives it its minutes back.
            override fun pause() {
                if (isSleepFading) restartSleepTimer() else this@AudiblePlayer.pause()
            }

            override fun setPlayWhenReady(playWhenReady: Boolean) = if (playWhenReady) play() else pause()
            override fun seekTo(positionMs: Long) = seek(positionMs / 1000.0)
            override fun seekBack() = skip(-SKIP_INTERVAL)
            override fun seekForward() = skip(SKIP_INTERVAL)
            override fun seekToNext() = nextChapter()
            override fun seekToNextMediaItem() = nextChapter()
            override fun seekToPrevious() = previousChapter()
            override fun seekToPreviousMediaItem() = previousChapter()
            override fun stop() = this@AudiblePlayer.stop()

            override fun getAvailableCommands(): Player.Commands = super.getAvailableCommands().buildUpon()
                .addAll(Player.COMMAND_SEEK_TO_NEXT, Player.COMMAND_SEEK_TO_PREVIOUS)
                .build()

            override fun isCommandAvailable(command: Int): Boolean =
                command == Player.COMMAND_SEEK_TO_NEXT || command == Player.COMMAND_SEEK_TO_PREVIOUS || super.isCommandAvailable(command)
        }
    }

    /**
     * A headset's play: the listening plays, and a running timer starts over for as long as it
     * was set.
     */
    private fun playFromHeadset() {
        restartSleepTimer()
        if (!isPlaying) togglePlayPause()
    }

    companion object {
        /** The step of the ±30 s buttons, the notification's included. */
        const val SKIP_INTERVAL = 30.0

        /** How often a playing title saves its position on Audible, in seconds. */
        const val SAVE_INTERVAL = 30L

        /** The sleep timer's choices, in minutes. */
        val SLEEP_CHOICES = listOf(15, 20, 30)

        /** How long after the timer paused that a press or a shake still restarts it, in seconds. */
        const val SLEEP_RESTART_WINDOW = 30 * 60L

        /** How long the taps have to settle before the position goes to Audible, in seconds. */
        const val SEEK_SAVE_DELAY = 2.0

        /** How often the volume steps down during the fade. */
        private const val FADE_STEP_MS = 100L
        private const val TICK_MS = 500L

        /** How hard the phone is moved, in g, to count as a shake. */
        private const val SHAKE_FORCE = 2.7f

            private fun isConnectivityLoss(error: Throwable): Boolean {
            var current: Throwable? = error
            while (current != null) {
                if (current is IOException && current !is androidx.media3.exoplayer.drm.MediaDrmCallbackException) return true
                if (current is PlaybackException && current.errorCode in setOf(
                        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_FAILED,
                        PlaybackException.ERROR_CODE_IO_NETWORK_CONNECTION_TIMEOUT,
                    )
                ) {
                    return true
                }
                current = current.cause
            }
            return false
        }
    }
}

/**
 * Answers Media3's Widevine key requests: the request goes to Audible through the server, and
 * its licence is handed back to Android's DRM. The device's own provisioning, when it needs one,
 * goes to Google as it always does.
 */
private class WidevineKeys(private val client: ListeningClient, private val asin: () -> String?) : MediaDrmCallback {
    private val provisioning = HttpMediaDrmCallback(null, DefaultHttpDataSource.Factory())

    override fun executeProvisionRequest(uuid: UUID, request: ExoMediaDrm.ProvisionRequest): MediaDrmCallback.Response =
        provisioning.executeProvisionRequest(uuid, request)

    override fun executeKeyRequest(uuid: UUID, request: ExoMediaDrm.KeyRequest): MediaDrmCallback.Response {
        val asin = asin() ?: throw ListeningError.UnreadableKey()
        // Media3 asks on a thread of its own, and waits for the answer there.
        return MediaDrmCallback.Response(runBlocking { client.contentKey(asin, request.data) })
    }
}

/** The app's one player, created at its first use and kept as long as the process lives. */
object AudiblePlayers {
    @Volatile private var player: AudiblePlayer? = null

    fun app(context: Context): AudiblePlayer = player ?: synchronized(this) {
        player ?: AudiblePlayer(context.applicationContext, restoresLastTitle = true).also { player = it }
    }
}

/** Set once for the whole app by `ContentView`; null in previews, where nothing plays. */
val LocalAudiblePlayer = staticCompositionLocalOf<AudiblePlayer?> { null }
