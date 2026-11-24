package com.polyforms.shiori.features.listening

import android.util.Base64
import com.apollographql.apollo.api.Optional
import com.polyforms.shiori.graphql.AudibleWidevineKeyMutation
import com.polyforms.shiori.graphql.SaveAudiblePositionMutation
import com.polyforms.shiori.graphql.StartAudibleWidevinePlaybackMutation
import com.polyforms.shiori.shared.GraphQLClient
import com.polyforms.shiori.shared.parseISO8601
import kotlin.math.max

/**
 * The Audible player's three calls. None changes the library: a licence, a content key and a
 * saved position are Audible's, not Shiori's.
 */
object ListeningApi {
    /**
     * A licence for one title. `offline` asks for a download licence, whose key the phone may
     * keep: the title then plays with no network.
     */
    suspend fun start(asin: String, offline: Boolean): Playback {
        val playback = GraphQLClient.perform(
            StartAudibleWidevinePlaybackMutation(asin, Optional.present(offline)),
            changesLibrary = false,
        ).startAudiblePlayback
        if (!playback.streamUrl.startsWith("https://")) throw ListeningError.UnreadableLicence()
        return Playback(
            asin = playback.asin,
            contentReference = playback.contentReference,
            streamURL = playback.streamUrl,
            duration = playback.durationMs / 1000.0,
            chapters = playback.chapters.map { ListeningChapter(it.title, it.startMs / 1000.0, it.lengthMs / 1000.0) },
            resumeAt = playback.position?.let { it.positionMs / 1000.0 },
            resumeSavedAt = playback.position?.let { parseISO8601(it.savedAt) },
        )
    }

    /**
     * The licence for a Widevine key request. `offline` asks for one the phone may keep, for a
     * title started with a download licence.
     */
    suspend fun contentKey(asin: String, request: ByteArray, offline: Boolean): ByteArray {
        val data = GraphQLClient.perform(
            AudibleWidevineKeyMutation(asin, Base64.encodeToString(request, Base64.NO_WRAP), Optional.present(offline)),
            changesLibrary = false,
        )
        return runCatching { Base64.decode(data.audibleWidevineKey, Base64.DEFAULT) }.getOrNull()
            ?.takeIf { it.isNotEmpty() } ?: throw ListeningError.UnreadableKey()
    }

    suspend fun savePosition(asin: String, contentReference: String, position: Double) {
        GraphQLClient.perform(
            SaveAudiblePositionMutation(asin, contentReference, (max(0.0, position) * 1000).coerceAtMost(Int.MAX_VALUE.toDouble()).toInt()),
            changesLibrary = false,
        )
    }
}

sealed class ListeningError(message: String) : Exception(message) {
    class UnreadableLicence : ListeningError("unreadable licence")
    class UnreadableKey : ListeningError("unreadable key")
}
