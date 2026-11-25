package com.polyforms.shiori.features.friends

import org.junit.Assert.assertEquals
import org.junit.Test

class FriendsPickTest {
    @Test
    fun `an only friend stands picked, chosen or not`() {
        assertEquals(listOf("lea"), FriendsPick.shown(listOf("lea"), emptyList()))
        assertEquals(listOf("lea"), FriendsPick.shown(listOf("lea"), listOf("lea")))
    }

    @Test
    fun `several friends show the ones picked, nobody picked meaning everyone`() {
        assertEquals(emptyList<String>(), FriendsPick.shown(listOf("lea", "marc"), emptyList()))
        assertEquals(listOf("marc"), FriendsPick.shown(listOf("lea", "marc"), listOf("marc")))
    }

    @Test
    fun `no friend shows nobody, for the invitation`() {
        assertEquals(emptyList<String>(), FriendsPick.shown(emptyList(), emptyList()))
    }

    @Test
    fun `a friend gone drops out of the pick`() {
        assertEquals(listOf("marc"), FriendsPick.kept(listOf("lea", "marc", "sophie"), listOf("hugo", "marc")))
    }

    @Test
    fun `down to one friend or none, the pick is let go so a second friend finds everyone`() {
        assertEquals(emptyList<String>(), FriendsPick.kept(listOf("lea"), listOf("lea")))
        assertEquals(emptyList<String>(), FriendsPick.kept(emptyList(), listOf("lea")))
    }
}
