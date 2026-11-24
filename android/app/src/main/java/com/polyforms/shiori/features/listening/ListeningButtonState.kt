package com.polyforms.shiori.features.listening

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReadingStatus

/**
 * What the play button of an Audible audiobook says, on its page and on its "En cours" card:
 * listen to it, take it up again, pause it, or hear it again.
 */
enum class ListeningButtonState {
    /** Never opened on any Audible player: from the start. */
    LISTEN,

    /** Under way: from where the reader stopped, here or on Audible. */
    RESUME,

    /** Playing in Shiori now. */
    PAUSE,

    /** Finished: from the start again. */
    RELISTEN;

    val title: String
        get() = when (this) {
            LISTEN -> L("Écouter")
            RESUME -> L("Reprendre")
            PAUSE -> L("Pause")
            RELISTEN -> L("Réécouter")
        }

    val symbol: String
        get() = when (this) {
            LISTEN, RESUME -> "play.fill"
            PAUSE -> "pause.fill"
            RELISTEN -> "arrow.counterclockwise"
        }

    companion object {
        /**
         * The state of a book's button, or null when it plays nothing: a paper book, an audiobook
         * with no Audible page, or a screen given no player (a preview).
         */
        fun of(book: Book, player: AudiblePlayer?): ListeningButtonState? {
            if (player == null) return null
            val title = ListeningTitle.of(book) ?: return null
            val current = player.title?.asin == title.asin
            return of(book.status, book.listeningProgress, current, current && player.isPlaying)
        }

        /** The rule itself, apart from the player, so it is tested on its own. */
        fun of(status: ReadingStatus, progress: Int?, isCurrent: Boolean, isPlaying: Boolean): ListeningButtonState = when {
            isPlaying -> PAUSE
            isCurrent -> RESUME
            status == ReadingStatus.READ -> RELISTEN
            status == ReadingStatus.READING || (progress ?: 0) > 0 -> RESUME
            else -> LISTEN
        }
    }
}

/** What a tap on a book's play button does, given what the button said. */
fun AudiblePlayer.press(state: ListeningButtonState, book: Book) {
    val title = ListeningTitle.of(book) ?: return
    when (state) {
        ListeningButtonState.PAUSE -> pause()
        ListeningButtonState.RESUME, ListeningButtonState.LISTEN -> play(title)
        ListeningButtonState.RELISTEN -> play(title, fromStart = true)
    }
}
