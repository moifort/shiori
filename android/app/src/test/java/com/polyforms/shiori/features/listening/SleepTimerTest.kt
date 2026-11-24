package com.polyforms.shiori.features.listening

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant

@OptIn(ExperimentalCoroutinesApi::class)
class SleepTimerTest {
    private val start = Instant.ofEpochSecond(1_000_000)

    private fun timer(minutes: Int = 15) = SleepTimer.starting(minutes, start)

    private fun at(seconds: Double) = start.plusMillis((seconds * 1000).toLong())

    // The player's own timer runs on the main dispatcher, which a unit test has to stand in for.
    @Before
    fun setMain() = Dispatchers.setMain(StandardTestDispatcher())

    @After
    fun resetMain() = Dispatchers.resetMain()

    @Test
    fun `ends as many minutes after it was set as it was set to`() {
        assertEquals(at(900.0), timer(15).endsAt)
        assertEquals(at(1800.0), timer(30).endsAt)
    }

    @Test
    fun `plays at full volume until the fade, which takes the last seconds`() {
        assertEquals(5.0, SleepTimer.FADE_DURATION, 0.0)
        val timer = timer()
        assertEquals(at(900 - SleepTimer.FADE_DURATION), timer.fadeStartsAt)
        assertEquals(1f, timer.volume(at(0.0)))
        assertEquals(1f, timer.volume(at(600.0)))
        assertFalse(timer.isFading(at(600.0)))
    }

    @Test
    fun `falls steadily to silence over the fade`() {
        val timer = timer()
        val fadeStart = 900 - SleepTimer.FADE_DURATION
        assertTrue(timer.isFading(at(fadeStart)))
        assertEquals(1f, timer.volume(at(fadeStart)))
        assertEquals(0.25f, timer.volume(at(fadeStart + SleepTimer.FADE_DURATION / 2)))
        var previous = 1f
        (0..5).forEach { step ->
            val volume = timer.volume(at(fadeStart + step))
            assertTrue(volume <= previous)
            previous = volume
        }
        assertEquals(0f, timer.volume(at(900.0)))
    }

    @Test
    fun `is over once it ends, no more fade, the player pauses`() {
        val timer = timer()
        assertFalse(timer.isOver(at(899.0)))
        assertTrue(timer.isOver(at(900.0)))
        assertFalse(timer.isFading(at(900.0)))
        assertEquals(0f, timer.volume(at(1000.0)))
    }

    @Test
    fun `set again during the fade, it starts over at full volume`() {
        val restarted = SleepTimer.starting(15, at(897.0))
        assertEquals(at(1797.0), restarted.endsAt)
        assertEquals(1f, restarted.volume(at(897.0)))
        assertFalse(restarted.isFading(at(897.0)))
    }

    @Test
    fun `a running timer starts over for as long as it was set`() {
        val player = AudiblePlayer(null, ListeningClient.preview)
        player.toggleSleepTimer(15)
        val first = player.sleepTimer!!
        assertTrue(player.restartSleepTimer())
        val second = player.sleepTimer!!
        assertEquals(15, second.minutes)
        assertFalse(second.endsAt.isBefore(first.endsAt))
        assertFalse(player.isSleepFading)
    }

    @Test
    fun `no timer set, a press does nothing to it`() {
        val player = AudiblePlayer(null, ListeningClient.preview)
        assertFalse(player.restartSleepTimer())
        assertNull(player.sleepTimer)
    }

    @Test
    fun `the same choice again turns the timer off`() {
        val player = AudiblePlayer(null, ListeningClient.preview)
        player.toggleSleepTimer(20)
        player.toggleSleepTimer(20)
        assertNull(player.sleepTimer)
        assertFalse(player.restartSleepTimer())
    }
}
