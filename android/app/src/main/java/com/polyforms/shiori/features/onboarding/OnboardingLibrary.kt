package com.polyforms.shiori.features.onboarding

import com.polyforms.shiori.R
import com.polyforms.shiori.features.import.ImportSource
import com.polyforms.shiori.shared.L

/**
 * A library the onboarding brings in, one step each: the two Amazon connections and the Goodreads
 * export file. Each says, before any sign-in, what Shiori takes from it and what it leaves alone.
 */
enum class OnboardingLibrary {
    AUDIBLE, KINDLE, GOODREADS;

    val label: String get() = when (this) {
        AUDIBLE -> "Audible"
        KINDLE -> "Kindle"
        GOODREADS -> "Goodreads"
    }

    /** The service's one logo. */
    val logo: Int get() = when (this) {
        AUDIBLE -> ImportSource.AUDIBLE.logo
        KINDLE -> ImportSource.KINDLE.logo
        GOODREADS -> R.drawable.logo_goodreads
    }

    /** The Amazon connection behind the step; none for Goodreads, a file. */
    val amazonSource: ImportSource? get() = when (this) {
        AUDIBLE -> ImportSource.AUDIBLE
        KINDLE -> ImportSource.KINDLE
        GOODREADS -> null
    }

    /** One line the step pages draw: a symbol, a title, a detail. */
    data class Fact(val symbol: String, val title: String, val detail: String)

    val title: String get() = when (this) {
        AUDIBLE -> L("Votre bibliothèque Audible")
        KINDLE -> L("Votre bibliothèque Kindle")
        GOODREADS -> L("Votre bibliothèque Goodreads")
    }

    val summary: String get() = when (this) {
        AUDIBLE -> L("Shiori se connecte à Audible pour ranger vos livres audio avec les autres.")
        KINDLE -> L("Shiori se connecte à Kindle pour ranger vos livres numériques avec les autres.")
        GOODREADS -> L("Goodreads ne partage pas vos livres avec d'autres apps : Shiori lit son fichier d'export.")
    }

    /** What Shiori brings in from the library. */
    val brings: List<Fact> get() = when (this) {
        AUDIBLE -> listOf(
            Fact("books.vertical", L("Vos livres audio"), L("Tous les titres de votre bibliothèque Audible.")),
            Fact("chart.pie", L("Où vous en êtes"), L("La position d'écoute, et les livres finis.")),
            Fact("play.fill", L("Le lecteur"), L("Vos livres s'écoutent dans Shiori, là où vous en étiez.")),
        )
        KINDLE -> listOf(
            Fact("books.vertical", L("Vos livres numériques"), L("Tous les titres de votre bibliothèque Kindle.")),
            Fact("chart.pie", L("Votre progression"), L("Le pourcentage lu, et les livres finis.")),
            Fact("arrow.triangle.merge", L("Papier et Kindle, un seul livre"), L("Un livre que vous avez aussi en papier garde une seule fiche.")),
        )
        GOODREADS -> listOf(
            Fact("tray.2", L("Vos étagères"), L("Lus, en cours, à lire : chaque livre garde la sienne.")),
            Fact("star", L("Vos notes"), L("Les étoiles que vous avez données.")),
            Fact("calendar", L("Vos dates de lecture"), L("Quand vous avez commencé et fini chaque livre.")),
        )
    }

    /** What Shiori does not do with it: the sign-in stays with Amazon. */
    val leaves: List<Fact> get() = when (this) {
        AUDIBLE, KINDLE -> listOf(
            Fact("lock", L("Votre mot de passe reste chez Amazon"), L("Vous vous connectez sur sa page : Shiori ne le voit pas, et ne change rien à votre compte.")),
        )
        GOODREADS -> listOf(
            Fact("doc", L("Ni connexion ni mot de passe"), L("Seulement un fichier, que vous choisissez : votre compte Goodreads reste tel quel.")),
        )
    }

    val connectLabel: String get() = when (this) {
        AUDIBLE -> L("Connecter Audible")
        KINDLE -> L("Connecter Kindle")
        GOODREADS -> L("Importer depuis Goodreads")
    }

    val doneTitle: String get() = when (this) {
        AUDIBLE -> L("Audible connecté")
        KINDLE -> L("Kindle connecté")
        GOODREADS -> L("Import Goodreads lancé")
    }

    val doneSummary: String get() = when (this) {
        AUDIBLE -> L("Vos livres audio arrivent : Shiori les range pendant que vous continuez.")
        KINDLE -> L("Vos livres numériques arrivent : Shiori les range pendant que vous continuez.")
        GOODREADS -> L("Vos livres arrivent : Shiori lit le fichier pendant que vous continuez.")
    }

    val done: List<Fact> get() = when (this) {
        AUDIBLE -> listOf(
            Fact("arrow.down.to.line", L("Import en arrière-plan"), L("Ils apparaissent dans votre bibliothèque au fil de l'import.")),
            Fact("clock", L("À jour chaque nuit"), L("Vos nouveaux achats et votre écoute suivent, sans rien faire.")),
        )
        KINDLE -> listOf(
            Fact("arrow.down.to.line", L("Import en arrière-plan"), L("Ils apparaissent dans votre bibliothèque au fil de l'import.")),
            Fact("clock", L("À jour chaque nuit"), L("Vos nouveaux achats et votre lecture suivent, sans rien faire.")),
        )
        GOODREADS -> listOf(
            Fact("arrow.down.to.line", L("Import en arrière-plan"), L("Les livres en double avec Audible ou Kindle restent une seule fiche.")),
            Fact("doc", L("Un fichier, une fois"), L("Pour le mettre à jour, importez un nouvel export depuis les réglages.")),
        )
    }

    val failedTitle: String get() = when (this) {
        AUDIBLE -> L("Audible n'est pas connecté")
        KINDLE -> L("Kindle n'est pas connecté")
        GOODREADS -> L("Goodreads n'est pas importé")
    }

    companion object {
        /** The button that moves on from a library to [next], or into the app. */
        fun continueLabel(next: OnboardingLibrary?): String = when (next) {
            AUDIBLE -> L("Continuer avec Audible")
            KINDLE -> L("Continuer avec Kindle")
            GOODREADS -> L("Continuer avec Goodreads")
            null -> L("Terminer")
        }

        fun skipLabel(next: OnboardingLibrary?): String = when (next) {
            AUDIBLE -> L("Passer à Audible")
            KINDLE -> L("Passer à Kindle")
            GOODREADS -> L("Passer à Goodreads")
            null -> L("Terminer")
        }
    }
}

/**
 * Where the reader stands among the libraries they ticked: one step each, in the order the page
 * lists them, each shown, then connected or failed, before the next. Pure, so the order is tested
 * without a view.
 */
data class OnboardingLibrarySteps(val chosen: List<OnboardingLibrary>, val index: Int = 0, val phase: Phase = Phase.INTRO) {
    enum class Phase { INTRO, CONNECTED, FAILED }

    val current: OnboardingLibrary? get() = chosen.getOrNull(index)
    val next: OnboardingLibrary? get() = chosen.getOrNull(index + 1)
    /** "Étape 1 sur 3", counted from one. */
    val number: Int get() = index + 1
    val count: Int get() = chosen.size
    val isFinished: Boolean get() = current == null

    fun connected() = copy(phase = Phase.CONNECTED)
    fun failed() = copy(phase = Phase.FAILED)
    fun retry() = copy(phase = Phase.INTRO)

    /** On to the next library's page, whether this one was connected or skipped. */
    fun advance() = copy(index = index + 1, phase = Phase.INTRO)

    companion object {
        /** The ticked libraries in the order the steps go: Audible, Kindle, Goodreads. */
        fun of(chosen: Set<OnboardingLibrary>) = OnboardingLibrarySteps(OnboardingLibrary.entries.filter { it in chosen })
    }
}
