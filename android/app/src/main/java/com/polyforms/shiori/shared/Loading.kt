@file:OptIn(kotlinx.serialization.ExperimentalSerializationApi::class)

package com.polyforms.shiori.shared

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File

/** One page of a list the server cuts by cursor. */
data class CursorPage<Item>(val items: List<Item>, val hasMore: Boolean, val endCursor: String?) {
    companion object {
        /** A page cut from rows in memory, as the server cuts its own: for fixtures. */
        fun <Item> of(rows: List<Item>, limit: Int, after: String?, cursor: (Item) -> String): CursorPage<Item> {
            val start = after?.let { a -> rows.indexOfFirst { cursor(it) == a }.takeIf { it >= 0 }?.plus(1) } ?: 0
            val page = rows.drop(start).take(limit)
            return CursorPage(page, start + page.size < rows.size, page.lastOrNull()?.let(cursor))
        }
    }
}

/** One load of each kind at a time; a load asked while one runs rides on it or reruns it. */
class LoadGate<Kind> {
    private val running = mutableSetOf<Kind>()
    private val stale = mutableSetOf<Kind>()
    private val mutex = Mutex()

    fun isStale(kind: Kind): Boolean = kind in stale

    suspend fun run(kind: Kind, again: Boolean, load: suspend () -> Unit) {
        val started = mutex.withLock {
            if (!running.add(kind)) {
                if (again) stale.add(kind)
                false
            } else {
                true
            }
        }
        if (!started) return
        try {
            do {
                mutex.withLock { stale.remove(kind) }
                load()
            } while (mutex.withLock { kind in stale })
        } finally {
            mutex.withLock { running.remove(kind) }
        }
    }
}

val snapshotJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
}

/**
 * What a screen showed last time, kept on disk so a relaunch opens on it instead of a loader.
 * Bump `version` whenever the value changes shape.
 */
class SnapshotCache<Value>(private val name: String, private val version: Int, private val serializer: KSerializer<Value>) {
    @Serializable
    private data class Stored(val version: Int, val value: String)

    private val file: File get() = File(SnapshotCaches.folder, "$name.json")

    fun read(): Value? {
        if (Showcase.isOn) return null
        return runCatching {
            val stored = snapshotJson.decodeFromString(Stored.serializer(), file.readText())
            if (stored.version != version) null else snapshotJson.decodeFromString(serializer, stored.value)
        }.getOrNull()
    }

    fun write(value: Value) {
        if (Showcase.isOn) return
        runCatching {
            SnapshotCaches.folder.mkdirs()
            val stored = Stored(version, snapshotJson.encodeToString(serializer, value))
            val temp = File(SnapshotCaches.folder, "$name.json.tmp")
            temp.writeText(snapshotJson.encodeToString(Stored.serializer(), stored))
            temp.renameTo(file)
        }
    }

    fun forget() {
        file.delete()
    }
}

object SnapshotCaches {
    val folder: File get() = File(AppContext.get().cacheDir, "snapshots")
    fun clear() {
        folder.deleteRecursively()
    }
}
