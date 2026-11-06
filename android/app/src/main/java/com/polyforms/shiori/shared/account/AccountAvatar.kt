package com.polyforms.shiori.shared.account

import com.polyforms.shiori.R
import com.polyforms.shiori.shared.L
import com.polyforms.shiori.shared.SystemTint

/** A hero of fiction a reader can wear as their face. */
enum class AvatarHero {
    ALICE, DOROTHY, MERLIN, DRACULA,
    NEMO, CREATURE, TIME_TRAVELLER, INVISIBLE_MAN,
    HOLMES, LUPIN, DUPIN, ROULETABILLE,
    CARL, DONUT, DANEEL, SELDON, YE_WENJIE, LUO_JI, SHRIKE, PAUL_ATREIDES, MURDERBOT, ROCKY,
    GANDALF, KVOTHE, VIN, LOCKE_LAMORA, VIOLET, GERALT,
    LISBETH, POIROT, MAIGRET, REACHER,
    BILBO, TYRION, ARYA, HARRY, HERMIONE, KALADIN,
    ENDER, WATNEY, KATNISS, ARTHUR_DENT, MARVIN, BREQ,
    ADAMSBERG, HARRY_HOLE, WALLANDER, BOSCH;

    /** The schema's name for it: `TIME_TRAVELLER`. */
    val graphQLName: String get() = name

    val imageRes: Int
        get() = when (this) {
            ALICE -> R.drawable.avatar_alice
            DOROTHY -> R.drawable.avatar_dorothy
            MERLIN -> R.drawable.avatar_merlin
            DRACULA -> R.drawable.avatar_dracula
            NEMO -> R.drawable.avatar_nemo
            CREATURE -> R.drawable.avatar_creature
            TIME_TRAVELLER -> R.drawable.avatar_time_traveller
            INVISIBLE_MAN -> R.drawable.avatar_invisible_man
            HOLMES -> R.drawable.avatar_holmes
            LUPIN -> R.drawable.avatar_lupin
            DUPIN -> R.drawable.avatar_dupin
            ROULETABILLE -> R.drawable.avatar_rouletabille
            CARL -> R.drawable.avatar_carl
            DONUT -> R.drawable.avatar_donut
            DANEEL -> R.drawable.avatar_daneel
            SELDON -> R.drawable.avatar_seldon
            YE_WENJIE -> R.drawable.avatar_ye_wenjie
            LUO_JI -> R.drawable.avatar_luo_ji
            SHRIKE -> R.drawable.avatar_shrike
            PAUL_ATREIDES -> R.drawable.avatar_paul_atreides
            MURDERBOT -> R.drawable.avatar_murderbot
            ROCKY -> R.drawable.avatar_rocky
            GANDALF -> R.drawable.avatar_gandalf
            KVOTHE -> R.drawable.avatar_kvothe
            VIN -> R.drawable.avatar_vin
            LOCKE_LAMORA -> R.drawable.avatar_locke_lamora
            VIOLET -> R.drawable.avatar_violet
            GERALT -> R.drawable.avatar_geralt
            LISBETH -> R.drawable.avatar_lisbeth
            POIROT -> R.drawable.avatar_poirot
            MAIGRET -> R.drawable.avatar_maigret
            REACHER -> R.drawable.avatar_reacher
            BILBO -> R.drawable.avatar_bilbo
            TYRION -> R.drawable.avatar_tyrion
            ARYA -> R.drawable.avatar_arya
            HARRY -> R.drawable.avatar_harry
            HERMIONE -> R.drawable.avatar_hermione
            KALADIN -> R.drawable.avatar_kaladin
            ENDER -> R.drawable.avatar_ender
            WATNEY -> R.drawable.avatar_watney
            KATNISS -> R.drawable.avatar_katniss
            ARTHUR_DENT -> R.drawable.avatar_arthur_dent
            MARVIN -> R.drawable.avatar_marvin
            BREQ -> R.drawable.avatar_breq
            ADAMSBERG -> R.drawable.avatar_adamsberg
            HARRY_HOLE -> R.drawable.avatar_harry_hole
            WALLANDER -> R.drawable.avatar_wallander
            BOSCH -> R.drawable.avatar_bosch
        }

    val displayName: String
        get() = when (this) {
            ALICE -> L("Alice")
            DOROTHY -> L("Dorothy")
            MERLIN -> L("Merlin")
            DRACULA -> L("Dracula")
            NEMO -> L("Nemo")
            CREATURE -> L("La Créature")
            TIME_TRAVELLER -> L("Le Voyageur")
            INVISIBLE_MAN -> L("L'Homme invisible")
            HOLMES -> L("Sherlock Holmes")
            LUPIN -> L("Arsène Lupin")
            DUPIN -> L("Dupin")
            ROULETABILLE -> L("Rouletabille")
            CARL -> L("Carl")
            DONUT -> L("Donut")
            DANEEL -> L("Daneel Olivaw")
            SELDON -> L("Hari Seldon")
            YE_WENJIE -> L("Ye Wenjie")
            LUO_JI -> L("Luo Ji")
            SHRIKE -> L("Le Gritche")
            PAUL_ATREIDES -> L("Paul Atréides")
            MURDERBOT -> L("AssaSynth")
            ROCKY -> L("Rocky")
            GANDALF -> L("Gandalf")
            KVOTHE -> L("Kvothe")
            VIN -> L("Vin")
            LOCKE_LAMORA -> L("Locke Lamora")
            VIOLET -> L("Violet")
            GERALT -> L("Geralt")
            LISBETH -> L("Lisbeth Salander")
            POIROT -> L("Hercule Poirot")
            MAIGRET -> L("Maigret")
            REACHER -> L("Jack Reacher")
            BILBO -> L("Bilbo")
            TYRION -> L("Tyrion")
            ARYA -> L("Arya")
            HARRY -> L("Harry Potter")
            HERMIONE -> L("Hermione")
            KALADIN -> L("Kaladin")
            ENDER -> L("Ender")
            WATNEY -> L("Mark Watney")
            KATNISS -> L("Katniss")
            ARTHUR_DENT -> L("Arthur Dent")
            MARVIN -> L("Marvin")
            BREQ -> L("Breq")
            ADAMSBERG -> L("Adamsberg")
            HARRY_HOLE -> L("Harry Hole")
            WALLANDER -> L("Wallander")
            BOSCH -> L("Harry Bosch")
        }

    val isClassic: Boolean
        get() = this in setOf(ALICE, DOROTHY, MERLIN, DRACULA, NEMO, CREATURE, TIME_TRAVELLER, INVISIBLE_MAN, HOLMES, LUPIN, DUPIN, ROULETABILLE)

    val shelf: Shelf
        get() = when (this) {
            ALICE, DOROTHY, MERLIN, DRACULA, GANDALF, KVOTHE, VIN, LOCKE_LAMORA, VIOLET, GERALT, CARL, DONUT,
            BILBO, TYRION, ARYA, HARRY, HERMIONE, KALADIN -> Shelf.FANTASY
            NEMO, CREATURE, TIME_TRAVELLER, INVISIBLE_MAN, DANEEL, SELDON, YE_WENJIE, LUO_JI, SHRIKE,
            PAUL_ATREIDES, MURDERBOT, ROCKY, ENDER, WATNEY, KATNISS, ARTHUR_DENT, MARVIN, BREQ -> Shelf.SCIENCE_FICTION
            else -> Shelf.CRIME
        }

    enum class Shelf {
        FANTASY, SCIENCE_FICTION, CRIME;

        val title: String
            get() = when (this) {
                FANTASY -> L("Fantasy")
                SCIENCE_FICTION -> L("Science-fiction")
                CRIME -> L("Polar")
            }

        val heroes: List<AvatarHero>
            get() {
                val shelved = AvatarHero.entries.filter { it.shelf == this }
                return shelved.filter { !it.isClassic } + shelved.filter { it.isClassic }
            }
    }

    companion object {
        fun ofGraphQL(name: String): AvatarHero? = entries.firstOrNull { it.graphQLName == name }
    }
}

/** A plain colour behind the reader's initials. */
enum class AvatarColor {
    PINK, GREEN, BLUE, ORANGE, PURPLE, RED;

    val graphQLName: String get() = name

    val displayName: String
        get() = when (this) {
            PINK -> L("Rose")
            GREEN -> L("Vert")
            BLUE -> L("Bleu")
            ORANGE -> L("Orange")
            PURPLE -> L("Lilas")
            RED -> L("Rouge")
        }

    val tint: SystemTint
        get() = when (this) {
            PINK -> SystemTint.PINK
            GREEN -> SystemTint.GREEN
            BLUE -> SystemTint.BLUE
            ORANGE -> SystemTint.ORANGE
            PURPLE -> SystemTint.PURPLE
            RED -> SystemTint.RED
        }
}

/** The face a reader shows: their initials, a colour, a hero, or their photo. */
sealed interface AccountAvatar {
    data object Initials : AccountAvatar
    data class Tinted(val color: AvatarColor) : AccountAvatar
    data class Hero(val hero: AvatarHero) : AccountAvatar
    data class Photo(val url: String) : AccountAvatar
    data class PickedPhoto(val data: ByteArray) : AccountAvatar
}

/** "TM" for "Thibaut Mottet": the first letters of the first two words. */
fun initials(name: String?): String =
    (name ?: "").split(' ', '-').filter { it.isNotEmpty() }.take(2).map { it.first().uppercase() }.joinToString("")

/** A photo cropped to its centre square at 512 pixels, as the avatar upload takes it. */
fun squarePhoto(data: ByteArray): ByteArray? {
    val image = android.graphics.BitmapFactory.decodeByteArray(data, 0, data.size) ?: return null
    val side = minOf(image.width, image.height)
    val square = android.graphics.Bitmap.createBitmap(image, (image.width - side) / 2, (image.height - side) / 2, side, side)
    val scaled = android.graphics.Bitmap.createScaledBitmap(square, 512, 512, true)
    return java.io.ByteArrayOutputStream().use { out ->
        scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, out)
        out.toByteArray()
    }
}
