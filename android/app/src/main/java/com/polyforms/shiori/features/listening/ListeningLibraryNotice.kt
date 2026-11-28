package com.polyforms.shiori.features.listening

/**
 * When a position the player sent should tell the library it changed.
 *
 * The server moves the book with every position it is sent: a book on the pile goes under way
 * with the first one, sent as soon as the title sounds, its progress follows, and it is read once
 * heard to its closing credits. Accueil and the lists only show it once told. Telling them at
 * every half-minute save would reload every open tab twice a minute, so they hear of it on the
 * first save of a title — the book just left the pile — when the reader stops (a pause, a seek,
 * the app left, another title), and at the end.
 */
class ListeningLibraryNotice {
    /** Titles whose first save this listen already announced. */
    private val announced = mutableSetOf<String>()

    /**
     * Whether this sent position should be announced. [periodic] is the half-minute save of a
     * title playing; every other save is the title starting or the reader stopping somewhere.
     */
    fun shouldAnnounce(asin: String, position: Double, duration: Double, periodic: Boolean): Boolean {
        if (duration > 0 && position >= duration - FINISHED_WITHIN) return true
        val first = announced.add(asin)
        return first || !periodic
    }

    companion object {
        /** The server's own margin for a book heard to its end. */
        const val FINISHED_WITHIN = 3 * 60.0
    }
}
