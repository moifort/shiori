package com.polyforms.shiori

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.disk.DiskCache
import coil3.disk.directory
import coil3.memory.MemoryCache
import coil3.request.crossfade
import com.google.firebase.FirebaseApp
import com.polyforms.shiori.shared.Analytics
import com.polyforms.shiori.shared.AppContext
import com.polyforms.shiori.shared.Strings
import io.sentry.android.core.SentryAndroid

class ShioriApplication : Application(), SingletonImageLoader.Factory {
    override fun onCreate() {
        super.onCreate()
        AppContext.set(this)
        Strings.load(this)
        FirebaseApp.initializeApp(this)
        Analytics.start(this)
        com.polyforms.shiori.shared.PushRegistrar.createChannel(this)
        startSentry()
    }

    /**
     * Debug builds never start Sentry, so their noise stays out of the production project; a
     * release build reports when its DSN was given at build time.
     */
    private fun startSentry() {
        if (BuildConfig.DEBUG || BuildConfig.SENTRY_DSN.isEmpty()) return
        SentryAndroid.init(this) { options ->
            options.dsn = BuildConfig.SENTRY_DSN
            options.tracesSampleRate = 0.1
            options.isEnableAutoSessionTracking = true
            options.setTracePropagationTargets(listOf(BuildConfig.SERVER_URL))
        }
    }

    /** Covers: a quarter of the memory class in memory, 250 MB on disk, as iOS keeps them. */
    override fun newImageLoader(context: PlatformContext): ImageLoader =
        ImageLoader.Builder(context)
            .memoryCache { MemoryCache.Builder().maxSizePercent(context, 0.25).build() }
            .diskCache { DiskCache.Builder().directory(cacheDir.resolve("covers")).maxSizeBytes(250L * 1024 * 1024).build() }
            .crossfade(true)
            .build()
}
