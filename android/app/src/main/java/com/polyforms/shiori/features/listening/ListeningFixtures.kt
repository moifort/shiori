package com.polyforms.shiori.features.listening

val ListeningTitlePreview = ListeningTitle(
    asin = "B077PLB5KD",
    title = "Endymion",
    subtitle = "Les Cantos d'Hypérion · Tome 3",
    coverURL = "https://m.media-amazon.com/images/I/514Pw3mZUQL._SL500_.jpg",
)

/**
 * Endymion, 21 h 49 long, 40 chapters, the reader 18:42 into the twelfth: 11 h 47 left, 46 %
 * heard — the figures the board draws.
 */
val Playback.Companion.preview: Playback
    get() {
        val opening = (0 until 11).map { ListeningChapter("Chapitre ${it + 1}", it * 3183.0, 3183.0) }
        val twelfth = ListeningChapter("Chapitre 12", 35013.0, 1678.0)
        val closing = (0 until 28).map { ListeningChapter("Chapitre ${it + 13}", 36691 + it * 1494.96, 1494.96) }
        return Playback(
            asin = "B077PLB5KD",
            contentReference = "preview",
            streamURL = "https://example.com/preview.mpd",
            duration = 78550.0,
            chapters = opening + twelfth + closing,
            resumeAt = 36135.0,
        )
    }

val ListeningProgress.Companion.preview: ListeningProgress
    get() = Playback.preview.let { ListeningProgress(it.resumeAt ?: 0.0, it.duration, it.chapters) }

/** What follows Endymion on the board: one recording under way, then the pile. */
val ListeningQueuePreviews: List<ListeningQueueEntry> = listOf(
    queueEntry("seul-sur-mars", "Seul sur Mars", "Andy Weir", "9780553418026", heard = 32),
    queueEntry("eveil-endymion", "L'Éveil d'Endymion", "Les Cantos d'Hypérion · Tome 4", "9780553572988"),
    queueEntry("projet-derniere-chance", "Projet Dernière Chance", "Andy Weir", "9780593135204"),
    queueEntry("nom-du-vent", "Le Nom du vent", "Chronique du tueur de roi · Tome 1", "9780756404741"),
    queueEntry("assasynth", "Journal d'un AssaSynth", "Martha Wells", "9780765397539"),
    queueEntry("trois-corps", "Le Problème à trois corps", "Le Problème à trois corps · Tome 1", "9780765382030"),
)

private fun queueEntry(asin: String, title: String, subtitle: String, isbn: String, heard: Int? = null) =
    ListeningQueueEntry(ListeningTitle(asin, title, subtitle, "https://covers.openlibrary.org/b/isbn/$isbn-L.jpg"), heard)
