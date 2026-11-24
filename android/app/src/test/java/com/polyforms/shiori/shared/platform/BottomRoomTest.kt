package com.polyforms.shiori.shared.platform

import androidx.compose.ui.unit.dp
import org.junit.Assert.assertEquals
import org.junit.Test

class BottomRoomTest {
    private val navigation = 24.dp

    @Test
    fun `the bar alone covers its capsule, its padding and the system navigation`() {
        assertEquals(98.dp, BottomRoom.covered(navigation, accessory = null))
    }

    @Test
    fun `the title playing adds its height and its gap above the bar`() {
        assertEquals(162.dp, BottomRoom.covered(navigation, accessory = 56.dp))
    }

    @Test
    fun `a page ends with the room iOS leaves after the bar`() {
        assertEquals(32.dp, BottomRoom.PageEndMargin)
        assertEquals(194.dp, BottomRoom.covered(navigation, accessory = 56.dp) + BottomRoom.PageEndMargin)
    }
}
