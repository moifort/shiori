package com.polyforms.shiori.features.listening

import com.polyforms.shiori.features.home.HomeApi

/** What the player asks of the server. */
interface ListeningClient {
    /** A licence to play one title. */
    suspend fun start(asin: String): Playback

    /** The licence answering a Widevine key request. */
    suspend fun contentKey(asin: String, request: ByteArray): ByteArray

    suspend fun savePosition(asin: String, contentReference: String, position: Double)

    /**
     * The audiobooks to play once this one ends, in order: the Audible titles under way, the last
     * one started first, then the pile, the last one shelved first, this one aside. The player
     * plays the first; the queue shows them all, so what it lists is what follows.
     */
    suspend fun queue(after: String): List<ListeningQueueEntry>

    companion object {
        val live: ListeningClient = object : ListeningClient {
            override suspend fun start(asin: String) = ListeningApi.start(asin, offline = false)
            override suspend fun contentKey(asin: String, request: ByteArray) = ListeningApi.contentKey(asin, request, offline = false)
            override suspend fun savePosition(asin: String, contentReference: String, position: Double) =
                ListeningApi.savePosition(asin, contentReference, position)

            override suspend fun queue(after: String): List<ListeningQueueEntry> {
                // The home's "En cours", the last one started first, then its pile, the last one
                // shelved first.
                val dashboard = HomeApi.dashboard()
                val seen = mutableSetOf(after)
                return (dashboard.reading + dashboard.toRead).mapNotNull(ListeningQueueEntry::of).filter { seen.add(it.id) }
            }
        }

        /** Answers a licence with no stream behind it: enough for previews, where nothing plays. */
        val preview: ListeningClient = object : ListeningClient {
            override suspend fun start(asin: String) = Playback.preview
            override suspend fun contentKey(asin: String, request: ByteArray) = ByteArray(0)
            override suspend fun savePosition(asin: String, contentReference: String, position: Double) = Unit
            override suspend fun queue(after: String) = ListeningQueuePreviews
        }
    }
}
