package com.polyforms.shiori.features.friends

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.Instant

class ReadingChallengeTest {
    private fun friend(id: String, read: Int) = Friend(id, id.replaceFirstChar { it.uppercase() }, Instant.EPOCH, readThisYear = read)

    @Test
    fun `ties share a rank, the reader first among them`() {
        val challenge = ReadingChallenge(friend("me", 4), listOf(friend("lea", 4), friend("hugo", 9)))

        assertEquals(listOf("hugo", "me", "lea"), challenge.entries.map { it.id })
        assertEquals(listOf(1, 2, 2), challenge.entries.map { it.rank })
    }

    @Test
    fun `the reader's own row follows the top five when further down`() {
        val friends = (1..6).map { friend("f$it", 10 + it) }
        val challenge = ReadingChallenge(friend("me", 1), friends)

        assertEquals(6, challenge.visible.size)
        assertEquals("me", challenge.visible.last().id)
    }

    @Test
    fun `says how many books it takes to overtake the friend just above`() {
        val behind = ReadingChallenge(friend("me", 3), listOf(friend("lea", 5), friend("hugo", 9)))
        assertEquals("figure.run", behind.verdict.symbol)

        val leading = ReadingChallenge(friend("me", 9), listOf(friend("lea", 5)))
        assertEquals("trophy.fill", leading.verdict.symbol)

        val nobody = ReadingChallenge(friend("me", 0), listOf(friend("lea", 0)))
        assertEquals("flag.checkered", nobody.verdict.symbol)
    }
}
