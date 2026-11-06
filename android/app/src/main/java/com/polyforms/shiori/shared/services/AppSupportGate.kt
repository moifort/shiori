package com.polyforms.shiori.shared.services

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.polyforms.shiori.BuildConfig
import com.polyforms.shiori.shared.ApiEndpoint
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.net.HttpURLConnection
import java.net.URL

/** Whether this build still works with the deployed server: the floor `app-config` gives. */
class AppSupportGate {
    sealed interface State {
        data object Supported : State
        data class UpdateRequired(val storeURL: String) : State
    }

    var state by mutableStateOf<State>(State.Supported)
        private set

    @Serializable
    private data class AppConfig(val minimumSupportedAndroidBuild: Int = 1, val playStoreUrl: String = "")

    /** Debug builds skip the gate; a failed check keeps the app usable. */
    suspend fun check() {
        if (BuildConfig.DEBUG) return
        val config = withContext(Dispatchers.IO) {
            runCatching {
                val connection = URL(ApiEndpoint.baseURL.trimEnd('/') + "/app-config").openConnection() as HttpURLConnection
                connection.useCaches = false
                connection.inputStream.bufferedReader().use { it.readText() }
            }.getOrNull()
        } ?: return
        val parsed = runCatching { Json { ignoreUnknownKeys = true }.decodeFromString(AppConfig.serializer(), config) }.getOrNull() ?: return
        state = if (BuildConfig.VERSION_CODE < parsed.minimumSupportedAndroidBuild) State.UpdateRequired(parsed.playStoreUrl) else State.Supported
    }
}
