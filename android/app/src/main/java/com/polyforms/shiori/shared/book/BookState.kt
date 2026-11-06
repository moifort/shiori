package com.polyforms.shiori.shared.book

import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.ReleaseDateText
import com.polyforms.shiori.shared.SystemTint

/** A line under a book page's hero that says where the book stands for the reader. */
data class BookState(val text: String, val tint: SystemTint) {
    companion object {

        fun release(date: String?): BookState {
            if (date == null) return BookState(L("Annoncé"), SystemTint.GRAY)
            return if (ReleaseDateText.isUpcoming(date)) {
                BookState(ReleaseDateText.coming(date), SystemTint.ORANGE)
            } else {
                BookState(ReleaseDateText.out(date), SystemTint.GREEN)
            }
        }

        val forthcoming get() = BookState(L("Pas encore paru"), SystemTint.GRAY)
        val owned get() = BookState(L("Déjà dans votre bibliothèque"), SystemTint.GREEN)
        val addedToPile get() = BookState(L("Ajouté à votre pile à lire"), SystemTint.GREEN)
        val addedAsRead get() = BookState(L("Ajouté à vos livres lus"), SystemTint.GREEN)
    }
}
