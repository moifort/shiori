package com.polyforms.shiori.features.listening

import java.time.Duration
import java.time.Instant
import kotlin.math.min

/**
 * The sleep timer's schedule: the listening plays at full volume, then, over its last seconds,
 * fades out to silence, which warns a listener half asleep that it is about to stop, and pauses
 * once the silence is reached.
 *
 * Pure: the player asks it the volume at a given time and whether the fade has begun, and does
 * the rest.
 */
data class SleepTimer(
    /** What the timer was set to, in minutes. */
    val minutes: Int,
    /** When the player pauses. */
    val endsAt: Instant,
) {
    /** When the volume starts to fall: never before the timer was set, for a timer shorter than the fade. */
    val fadeStartsAt: Instant
        get() = endsAt.minusMillis((min(FADE_DURATION, minutes * 60.0) * 1000).toLong())

    /** Whether the volume is falling at `now`. */
    fun isFading(now: Instant): Boolean = !now.isBefore(fadeStartsAt) && now.isBefore(endsAt)

    /** Whether the timer has run out at `now`: the player pauses. */
    fun isOver(now: Instant): Boolean = !now.isBefore(endsAt)

    /**
     * The player's volume at `now`, from 1 down to 0. The fall follows the square of the time
     * left, which the ear hears as a steady fade rather than one that lingers loud and drops at
     * the end.
     */
    fun volume(now: Instant): Float {
        val span = Duration.between(fadeStartsAt, endsAt).toMillis().toDouble()
        if (span <= 0) return if (isOver(now)) 0f else 1f
        val left = (Duration.between(now, endsAt).toMillis() / span).coerceIn(0.0, 1.0)
        return (left * left).toFloat()
    }

    companion object {
        /** A timer of `minutes` set at `start`. */
        fun starting(minutes: Int, start: Instant) = SleepTimer(minutes, start.plusSeconds(minutes * 60L))

        /** How long the volume takes to fall to silence before the pause, in seconds. */
        const val FADE_DURATION = 5.0
    }
}
