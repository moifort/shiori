package com.polyforms.shiori.shared

import kotlinx.serialization.Serializable
import java.util.Locale

/** The language an edition is printed or recorded in — never the language of the app. */
@Serializable
enum class BookLanguage {
    FR, EN, ES, DE, IT, PT, NL, SV, PL, RU, UK, TR, AR, JA, ZH, KO;

    val label: String
        get() = when (this) {
            FR -> L("Français")
            EN -> L("Anglais")
            ES -> L("Espagnol")
            DE -> L("Allemand")
            IT -> L("Italien")
            PT -> L("Portugais")
            NL -> L("Néerlandais")
            SV -> L("Suédois")
            PL -> L("Polonais")
            RU -> L("Russe")
            UK -> L("Ukrainien")
            TR -> L("Turc")
            AR -> L("Arabe")
            JA -> L("Japonais")
            ZH -> L("Chinois")
            KO -> L("Coréen")
        }

    /** Whether a language tag is worth drawing: the edition is not in the phone's language. */
    val isForeign: Boolean get() = this != device

    /** "EN", "JA". */
    val code: String get() = name

    companion object {
        fun of(code: String?): BookLanguage? = code?.let { c -> entries.firstOrNull { it.name.equals(c, true) } }

        val device: BookLanguage? get() = of(Locale.getDefault().language)

        val app: BookLanguage? get() = of(Strings.appLanguage)

        /** The editions a scan is checked against: the app's language, French and English. */
        val reviewChoices: List<BookLanguage>
            get() {
                val choices = app?.let { mutableListOf(it) } ?: mutableListOf()
                for (language in listOf(FR, EN)) if (language !in choices) choices += language
                return choices
            }

        fun presumed(scanned: BookLanguage?): BookLanguage? {
            if (scanned == null || scanned in reviewChoices) return app ?: scanned
            return scanned
        }
    }
}
