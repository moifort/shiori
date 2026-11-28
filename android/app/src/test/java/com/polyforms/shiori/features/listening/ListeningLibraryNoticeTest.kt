package com.polyforms.shiori.features.listening

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class ListeningLibraryNoticeTest {
    private val hours10 = 10 * 3600.0

    @Test
    fun `the save sent as the title starts announces the book under way, once`() {
        val notice = ListeningLibraryNotice()
        assertTrue(notice.shouldAnnounce("B1", 0.0, hours10, periodic = false))
        assertFalse(notice.shouldAnnounce("B1", 30.0, hours10, periodic = true))
        assertFalse(notice.shouldAnnounce("B1", 60.0, hours10, periodic = true))
    }

    @Test
    fun `a pause announces the progress, however early`() {
        val notice = ListeningLibraryNotice()
        notice.shouldAnnounce("B1", 0.0, hours10, periodic = false)
        assertTrue(notice.shouldAnnounce("B1", 5.0, hours10, periodic = false))
        assertTrue(notice.shouldAnnounce("B1", 600.0, hours10, periodic = false))
    }

    @Test
    fun `the end of the book is always announced`() {
        val notice = ListeningLibraryNotice()
        notice.shouldAnnounce("B1", 0.0, hours10, periodic = false)
        assertTrue(notice.shouldAnnounce("B1", hours10 - 60, hours10, periodic = true))
    }

    @Test
    fun `each title is announced on its own`() {
        val notice = ListeningLibraryNotice()
        assertTrue(notice.shouldAnnounce("B1", 120.0, hours10, periodic = true))
        assertTrue(notice.shouldAnnounce("B2", 120.0, hours10, periodic = true))
    }
}
