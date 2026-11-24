package com.polyforms.shiori.features.listening

import android.content.Context
import android.content.SharedPreferences
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.time.Instant

/**
 * Where the reader stopped in each Audible title, kept on the phone before it is sent to
 * Audible: a position saved with no network waits here and goes once the network is back, and a
 * downloaded title resumes from it offline.
 */
class ListeningPositions(private val store: KeyValueStore) {
    @Serializable
    data class Entry(
        val position: Double,
        val contentReference: String,
        /** Epoch milliseconds. */
        val savedAt: Long,
        /** Not yet on Audible. */
        val isPending: Boolean,
    )

    fun entry(asin: String): Entry? = all()[asin]

    /** The positions still to send to Audible. */
    fun pending(): Map<String, Entry> = all().filterValues { it.isPending }

    fun record(asin: String, position: Double, contentReference: String, now: Instant = Instant.now()) {
        write(all() + (asin to Entry(position, contentReference, now.toEpochMilli(), isPending = true)))
    }

    /** Audible has it: the entry stays, for an offline resume, but no longer waits. */
    fun markSent(asin: String, savedAt: Instant) {
        val entries = all()
        val entry = entries[asin]?.takeIf { it.savedAt == savedAt.toEpochMilli() } ?: return
        write(entries + (asin to entry.copy(isPending = false)))
    }

    fun forget(asin: String) = write(all() - asin)

    private fun all(): Map<String, Entry> =
        store.get(KEY)?.let { runCatching { json.decodeFromString<Map<String, Entry>>(it) }.getOrNull() } ?: emptyMap()

    private fun write(entries: Map<String, Entry>) = store.set(KEY, json.encodeToString(entries))

    companion object {
        private const val KEY = "audible.positions"
        private val json = Json { ignoreUnknownKeys = true }

        /**
         * Where to resume: the later of what Audible holds — another player may have gone on
         * since — and what this phone kept.
         */
        fun resume(audible: Double?, audibleSavedAt: Instant?, local: Entry?): Double? {
            if (local == null) return audible
            if (audible == null) return local.position
            if (audibleSavedAt == null) return if (local.isPending) local.position else audible
            return if (local.savedAt > audibleSavedAt.toEpochMilli()) local.position else audible
        }
    }
}

/**
 * The title listened to last, kept on the phone so the player finds it again after the app is
 * closed. Gone once the reader stops listening.
 */
class LastListenedTitle(private val store: KeyValueStore) {
    var value: ListeningTitle?
        get() = store.get(KEY)?.let { runCatching { Json.decodeFromString<ListeningTitle>(it) }.getOrNull() }
        set(title) = store.set(KEY, title?.let { Json.encodeToString(it) })

    private companion object {
        const val KEY = "audible.lastTitle"
    }
}

/** The few strings the player keeps on the phone: the preferences in the app, a map in a test. */
interface KeyValueStore {
    fun get(key: String): String?
    fun set(key: String, value: String?)

    class InMemory : KeyValueStore {
        private val values = mutableMapOf<String, String>()
        override fun get(key: String): String? = values[key]
        override fun set(key: String, value: String?) {
            if (value == null) values.remove(key) else values[key] = value
        }
    }

    class Preferences(context: Context) : KeyValueStore {
        private val preferences: SharedPreferences = context.getSharedPreferences("listening", Context.MODE_PRIVATE)
        override fun get(key: String): String? = preferences.getString(key, null)
        override fun set(key: String, value: String?) = preferences.edit().apply {
            if (value == null) remove(key) else putString(key, value)
        }.apply()
    }
}
