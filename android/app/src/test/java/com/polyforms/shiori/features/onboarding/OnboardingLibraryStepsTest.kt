package com.polyforms.shiori.features.onboarding

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class OnboardingLibraryStepsTest {
    @Test
    fun `steps follow the page order whatever the ticking order`() {
        val steps = OnboardingLibrarySteps.of(setOf(OnboardingLibrary.GOODREADS, OnboardingLibrary.AUDIBLE))
        assertEquals(listOf(OnboardingLibrary.AUDIBLE, OnboardingLibrary.GOODREADS), steps.chosen)
        assertEquals(OnboardingLibrary.AUDIBLE, steps.current)
        assertEquals(OnboardingLibrary.GOODREADS, steps.next)
        assertEquals(1, steps.number)
        assertEquals(2, steps.count)
    }

    @Test
    fun `each library is connected or skipped before the next`() {
        var steps = OnboardingLibrarySteps.of(OnboardingLibrary.entries.toSet()).connected()
        assertEquals(OnboardingLibrarySteps.Phase.CONNECTED, steps.phase)
        steps = steps.advance()
        assertEquals(OnboardingLibrary.KINDLE, steps.current)
        assertEquals(OnboardingLibrarySteps.Phase.INTRO, steps.phase)
        assertEquals(2, steps.number)
        steps = steps.failed().retry()
        assertEquals(OnboardingLibrarySteps.Phase.INTRO, steps.phase)
        steps = steps.advance()
        assertEquals(OnboardingLibrary.GOODREADS, steps.current)
        assertNull(steps.next)
        assertTrue(steps.advance().isFinished)
    }

    @Test
    fun `nothing ticked is finished at once`() {
        assertTrue(OnboardingLibrarySteps.of(emptySet()).isFinished)
    }
}
