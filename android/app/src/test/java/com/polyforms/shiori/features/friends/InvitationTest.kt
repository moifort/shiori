package com.polyforms.shiori.features.friends

import com.polyforms.shiori.shared.Book
import com.polyforms.shiori.shared.ReadingStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class InvitationTest {
    @Test
    fun `the install referrer carries the invitation, alone or among other parameters`() {
        assertEquals("AB12CD34", InstallInvitation.codeOfReferrer("invite=ab12cd34"))
        assertEquals("AB12CD34", InstallInvitation.codeOfReferrer("utm_source=web&invite=AB12CD34&utm_medium=link"))
    }

    @Test
    fun `a referrer without an invitation, or with a stray one, carries none`() {
        assertNull(InstallInvitation.codeOfReferrer("utm_source=google-play&utm_medium=organic"))
        assertNull(InstallInvitation.codeOfReferrer("invite=short"))
        assertNull(InstallInvitation.codeOfReferrer("invite="))
        assertNull(InstallInvitation.codeOfReferrer(""))
    }

    @Test
    fun `a code is eight letters or digits, upper-cased`() {
        assertEquals("AB12CD34", InvitationLink.normalized("ab12cd34"))
        assertNull(InvitationLink.normalized("ab12-d34"))
        assertNull(InvitationLink.normalized("AB12CD345"))
    }

    @Test
    fun `the rails narrow to the friends picked, and nobody picked keeps every friend`() {
        fun entry(friend: String, book: String) =
            FriendsShelfEntry(friend, friend, FriendBook(Book(id = book, title = book, authors = emptyList(), status = ReadingStatus.READING), false))
        val shelf = FriendsShelf(reading = listOf(entry("marc", "a"), entry("lea", "b")), pile = listOf(entry("lea", "c")))
        assertEquals(shelf, shelf.narrowed(emptyList()))
        assertEquals(listOf("b"), shelf.narrowed(listOf("lea")).reading.map { it.book.id })
        assertEquals(listOf("c"), shelf.narrowed(listOf("lea")).pile.map { it.book.id })
        assertEquals(true, shelf.narrowed(listOf("hugo")).isEmpty)
    }
}
