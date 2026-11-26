import SwiftUI

/// A library the onboarding brings in, one step each: the two Amazon
/// connections and the Goodreads export file. Each says, before any sign-in,
/// what Shiori takes from it and what it leaves alone.
enum OnboardingLibrary: String, CaseIterable, Identifiable, Sendable {
    case audible
    case kindle
    case goodreads

    var id: String { rawValue }

    var name: String {
        switch self {
        case .audible: "Audible"
        case .kindle: "Kindle"
        case .goodreads: "Goodreads"
        }
    }

    /// The service's one logo, from the asset catalogue.
    var logo: String {
        switch self {
        case .audible: ImportSource.audible.logo
        case .kindle: ImportSource.kindle.logo
        case .goodreads: "goodreads-logo"
        }
    }

    /// The Amazon connection behind the step; none for Goodreads, a file.
    var amazonSource: ImportSource? {
        switch self {
        case .audible: .audible
        case .kindle: .kindle
        case .goodreads: nil
        }
    }

    /// One line the step pages draw: a symbol, a title, a detail.
    struct Fact: Identifiable {
        let symbol: String
        let title: LocalizedStringResource
        let detail: LocalizedStringResource
        var id: String { symbol }
    }

    var title: LocalizedStringResource {
        switch self {
        case .audible: "Votre bibliothèque Audible"
        case .kindle: "Votre bibliothèque Kindle"
        case .goodreads: "Votre bibliothèque Goodreads"
        }
    }

    var summary: LocalizedStringResource {
        switch self {
        case .audible: "Shiori se connecte à Audible pour ranger vos livres audio avec les autres."
        case .kindle: "Shiori se connecte à Kindle pour ranger vos livres numériques avec les autres."
        case .goodreads: "Goodreads ne partage pas vos livres avec d'autres apps : Shiori lit son fichier d'export."
        }
    }

    /// What Shiori brings in from the library.
    var brings: [Fact] {
        switch self {
        case .audible: [
            Fact(symbol: "books.vertical", title: "Vos livres audio", detail: "Tous les titres de votre bibliothèque Audible."),
            Fact(symbol: "chart.pie", title: "Où vous en êtes", detail: "La position d'écoute, et les livres finis."),
            Fact(symbol: "play.fill", title: "Le lecteur", detail: "Vos livres s'écoutent dans Shiori, là où vous en étiez."),
        ]
        case .kindle: [
            Fact(symbol: "books.vertical", title: "Vos livres numériques", detail: "Tous les titres de votre bibliothèque Kindle."),
            Fact(symbol: "chart.pie", title: "Votre progression", detail: "Le pourcentage lu, et les livres finis."),
            Fact(symbol: "arrow.triangle.merge", title: "Papier et Kindle, un seul livre", detail: "Un livre que vous avez aussi en papier garde une seule fiche."),
        ]
        case .goodreads: [
            Fact(symbol: "tray.2", title: "Vos étagères", detail: "Lus, en cours, à lire : chaque livre garde la sienne."),
            Fact(symbol: "star", title: "Vos notes", detail: "Les étoiles que vous avez données."),
            Fact(symbol: "calendar", title: "Vos dates de lecture", detail: "Quand vous avez commencé et fini chaque livre."),
        ]
        }
    }

    /// What Shiori does not do with it: the sign-in stays with Amazon.
    var leaves: [Fact] {
        switch self {
        case .audible, .kindle: [
            Fact(symbol: "lock", title: "Votre mot de passe reste chez Amazon", detail: "Vous vous connectez sur sa page : Shiori ne le voit pas, et ne change rien à votre compte."),
        ]
        case .goodreads: [
            Fact(symbol: "doc", title: "Ni connexion ni mot de passe", detail: "Seulement un fichier, que vous choisissez : votre compte Goodreads reste tel quel."),
        ]
        }
    }

    var connectLabel: LocalizedStringResource {
        switch self {
        case .audible: "Connecter Audible"
        case .kindle: "Connecter Kindle"
        case .goodreads: "Importer depuis Goodreads"
        }
    }

    var doneTitle: LocalizedStringResource {
        switch self {
        case .audible: "Audible connecté"
        case .kindle: "Kindle connecté"
        case .goodreads: "Import Goodreads lancé"
        }
    }

    var doneSummary: LocalizedStringResource {
        switch self {
        case .audible: "Vos livres audio arrivent : Shiori les range pendant que vous continuez."
        case .kindle: "Vos livres numériques arrivent : Shiori les range pendant que vous continuez."
        case .goodreads: "Vos livres arrivent : Shiori lit le fichier pendant que vous continuez."
        }
    }

    var done: [Fact] {
        switch self {
        case .audible: [
            Fact(symbol: "arrow.down.to.line", title: "Import en arrière-plan", detail: "Ils apparaissent dans votre bibliothèque au fil de l'import."),
            Fact(symbol: "clock", title: "À jour chaque nuit", detail: "Vos nouveaux achats et votre écoute suivent, sans rien faire."),
        ]
        case .kindle: [
            Fact(symbol: "arrow.down.to.line", title: "Import en arrière-plan", detail: "Ils apparaissent dans votre bibliothèque au fil de l'import."),
            Fact(symbol: "clock", title: "À jour chaque nuit", detail: "Vos nouveaux achats et votre lecture suivent, sans rien faire."),
        ]
        case .goodreads: [
            Fact(symbol: "arrow.down.to.line", title: "Import en arrière-plan", detail: "Les livres en double avec Audible ou Kindle restent une seule fiche."),
            Fact(symbol: "doc", title: "Un fichier, une fois", detail: "Pour le mettre à jour, importez un nouvel export depuis les réglages."),
        ]
        }
    }

    var failedTitle: LocalizedStringResource {
        switch self {
        case .audible: "Audible n'est pas connecté"
        case .kindle: "Kindle n'est pas connecté"
        case .goodreads: "Goodreads n'est pas importé"
        }
    }

    /// The button that moves on from this library to `next`, or into the app.
    static func continueLabel(to next: OnboardingLibrary?) -> LocalizedStringResource {
        switch next {
        case .audible: "Continuer avec Audible"
        case .kindle: "Continuer avec Kindle"
        case .goodreads: "Continuer avec Goodreads"
        case nil: "Terminer"
        }
    }

    static func skipLabel(to next: OnboardingLibrary?) -> LocalizedStringResource {
        switch next {
        case .audible: "Passer à Audible"
        case .kindle: "Passer à Kindle"
        case .goodreads: "Passer à Goodreads"
        case nil: "Terminer"
        }
    }
}

/// Where the reader stands among the libraries they ticked: one step each, in
/// the order the page lists them, each shown, then connected or failed, before
/// the next. Pure, so the order is tested without a view.
struct OnboardingLibrarySteps: Equatable {
    enum Phase: Equatable {
        /// The page that says what the library is, before any sign-in.
        case intro
        case connected
        case failed
    }

    let chosen: [OnboardingLibrary]
    private(set) var index = 0
    private(set) var phase: Phase = .intro

    /// The ticked libraries in the order the steps go: Audible, Kindle, Goodreads.
    init(chosen: Set<OnboardingLibrary>) {
        self.chosen = OnboardingLibrary.allCases.filter(chosen.contains)
    }

    var current: OnboardingLibrary? { chosen.indices.contains(index) ? chosen[index] : nil }
    var next: OnboardingLibrary? { chosen.indices.contains(index + 1) ? chosen[index + 1] : nil }
    /// "Étape 1 sur 3", counted from one.
    var number: Int { index + 1 }
    var count: Int { chosen.count }
    var isFinished: Bool { current == nil }

    mutating func connected() { phase = .connected }
    mutating func failed() { phase = .failed }
    mutating func retry() { phase = .intro }

    /// On to the next library's page, whether this one was connected or skipped.
    mutating func advance() {
        index += 1
        phase = .intro
    }
}
