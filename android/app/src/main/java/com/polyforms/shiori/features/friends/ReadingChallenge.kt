package com.polyforms.shiori.features.friends

import com.polyforms.shiori.shared.L
import java.text.Collator

/**
 * The friends' reading challenge: the reader and everyone they share with, ranked on the books
 * each finished since January 1st, and one line that says where the reader stands.
 *
 * Ties share a rank, and the reader is listed first among those they tie with: it is their race
 * being told.
 */
class ReadingChallenge(me: Friend, friends: List<Friend>) {
    data class Entry(val id: String, val name: String, val count: Int, val isMe: Boolean, val rank: Int)

    /** Where the reader stands, in one line, and the symbol that goes with it. */
    data class Verdict(val text: String, val symbol: String)

    val entries: List<Entry>

    init {
        val collator = Collator.getInstance()
        val everyone = listOf(me to true) + friends.map { it to false }
        val sorted = everyone.sortedWith { left, right ->
            when {
                left.first.readThisYear != right.first.readThisYear -> right.first.readThisYear.compareTo(left.first.readThisYear)
                left.second != right.second -> if (left.second) -1 else 1
                else -> collator.compare(left.first.displayName, right.first.displayName)
            }
        }
        entries = sorted.map { (friend, isMe) ->
            Entry(
                id = friend.userId,
                name = if (isMe) L("Vous") else friend.displayName,
                count = friend.readThisYear,
                isMe = isMe,
                rank = 1 + sorted.count { it.first.readThisYear > friend.readThisYear },
            )
        }
    }

    val me: Entry? get() = entries.firstOrNull { it.isMe }

    /** The top of the ranking, and the reader's own row after it when they are further down. */
    val visible: List<Entry>
        get() {
            val top = entries.take(SHOWN)
            val me = me ?: return top
            return if (top.any { it.isMe }) top else top + me
        }

    val best: Int get() = entries.maxOfOrNull { it.count } ?: 0

    val verdict: Verdict
        get() {
            val me = me
            if (me == null || best == 0) {
                return Verdict(L("La course est ouverte : le premier livre terminé prend la tête."), "flag.checkered")
            }
            val others = entries.filter { !it.isMe }
            if (me.rank == 1) {
                val level = others.filter { it.count == me.count }
                level.firstOrNull()?.let { first ->
                    return if (level.size == 1) {
                        Verdict(L("Coude à coude avec %@ pour la première place !", first.name), "equal.circle.fill")
                    } else {
                        Verdict(L("Égalité en tête : %lld lecteurs se disputent la première place !", level.size + 1), "equal.circle.fill")
                    }
                }
                val second = others.firstOrNull() ?: return Verdict(L("Seul en piste : invitez un ami à vous défier !"), "trophy.fill")
                val lead = me.count - second.count
                return if (lead == 1) {
                    Verdict(L("Vous menez la course, un livre devant %@. Ne relâchez rien !", second.name), "trophy.fill")
                } else {
                    Verdict(L("Vous menez la course avec %lld livres d'avance sur %@ !", lead, second.name), "trophy.fill")
                }
            }
            // The friend just above: the smallest count still ahead of the reader.
            val ahead = others.filter { it.count > me.count }.minByOrNull { it.count } ?: return Verdict("", "figure.run")
            val needed = ahead.count - me.count + 1
            return if (needed == 1) {
                Verdict(L("Encore un livre et vous doublez %@ !", ahead.name), "figure.run")
            } else {
                Verdict(L("Encore %lld livres pour doubler %@. À vos pages !", needed, ahead.name), "figure.run")
            }
        }

    companion object {
        /** How many rows the card draws, the reader's own added when further down. */
        const val SHOWN = 5
    }
}
