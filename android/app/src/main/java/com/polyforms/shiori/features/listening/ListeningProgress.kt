package com.polyforms.shiori.features.listening

import com.polyforms.shiori.shared.L
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.max
import kotlin.math.min

/**
 * Where the listener stands in a recording, read against its chapters: the numbers every view of
 * the player draws, worked out once and tested apart from any view.
 */
data class ListeningProgress(
    val elapsed: Double,
    val duration: Double,
    val chapters: List<ListeningChapter>,
) {
    /**
     * The chapter playing, by its place in the list. Null before the licence is in, or on a
     * recording Audible gave no chapters.
     */
    val chapterIndex: Int?
        get() {
            if (chapters.isEmpty()) return null
            return chapters.indexOfLast { it.start <= elapsed + 0.5 }.takeIf { it >= 0 } ?: 0
        }

    val chapter: ListeningChapter? get() = chapterIndex?.let { chapters[it] }

    /** "Chapitre 12": the chapters are numbered by their place, whatever Audible titles them. */
    val chapterNumber: Int? get() = chapterIndex?.let { it + 1 }

    val chapterElapsed: Double
        get() {
            val chapter = chapter ?: return elapsed
            return min(max(0.0, elapsed - chapter.start), chapter.length)
        }

    val chapterRemaining: Double
        get() {
            val chapter = chapter ?: return max(0.0, duration - elapsed)
            return max(0.0, chapter.end - max(elapsed, chapter.start))
        }

    /** How far into the chapter, from 0 to 1: the bar of the full-screen player. */
    val chapterFraction: Double
        get() {
            val chapter = chapter
            if (chapter == null || chapter.length <= 0) return if (duration > 0) min(1.0, elapsed / duration) else 0.0
            return min(1.0, chapterElapsed / chapter.length)
        }

    val remaining: Double get() = max(0.0, duration - elapsed)

    /** Whole percent of the recording heard. */
    val percent: Int
        get() = if (duration > 0) min(100, floor(elapsed / duration * 100).toInt()) else 0

    /**
     * Where "previous chapter" goes: the start of this one, unless the listener is within its
     * first seconds, as every player does.
     */
    val previousChapterStart: Double
        get() {
            val index = chapterIndex ?: return 0.0
            return if (chapterElapsed > 3 || index == 0) chapters[index].start else chapters[index - 1].start
        }

    /** Where "next chapter" goes, or null in the last one. */
    val nextChapterStart: Double?
        get() {
            val index = chapterIndex ?: return null
            return chapters.getOrNull(index + 1)?.start
        }

    companion object
}

/** The player's time phrases, in the app's language. */
object ListeningText {
    /** "18:42", "1:02:05": a clock position, as the bar's labels draw it. */
    fun clock(seconds: Double): String {
        val total = floor(max(0.0, seconds)).toInt()
        val hours = total / 3600
        val minutes = total % 3600 / 60
        val secs = total % 60
        return if (hours > 0) "%d:%02d:%02d".format(hours, minutes, secs) else "%d:%02d".format(minutes, secs)
    }

    /** "11h47 restantes", "47 min restantes". */
    fun remaining(seconds: Double): String {
        val minutes = ceil(max(0.0, seconds) / 60).toInt()
        if (minutes >= 60) return L("%lldh%@ restantes", minutes / 60, "%02d".format(minutes % 60))
        return L("%lld min restantes", minutes)
    }

    /** "Chapitre 12 · 11h47 restantes", the accessory's second line. */
    fun accessoryLine(progress: ListeningProgress): String {
        val remaining = remaining(progress.remaining)
        val number = progress.chapterNumber ?: return remaining
        return L("Chapitre %lld · %@", number, remaining)
    }

    /** "Chap. 12 · 11h47", the folded bar's second line: the time left with no word. */
    fun shortLine(progress: ListeningProgress): String {
        val minutes = ceil(max(0.0, progress.remaining) / 60).toInt()
        val left = if (minutes >= 60) "${minutes / 60}h${"%02d".format(minutes % 60)}" else L("%lld min", minutes)
        val number = progress.chapterNumber ?: return left
        return L("Chap. %lld · %@", number, left)
    }

    /** "Chapitre 12 sur 40". */
    fun chapterOfCount(progress: ListeningProgress): String? =
        progress.chapterNumber?.let { L("Chapitre %lld sur %lld", it, progress.chapters.size) }

    /** "11h47 restantes · 46%". */
    fun summary(progress: ListeningProgress): String = "${remaining(progress.remaining)} · ${progress.percent}%"
}
