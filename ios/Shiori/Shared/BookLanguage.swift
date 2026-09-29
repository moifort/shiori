import Foundation

/// The language an edition is printed or recorded in — the object on the shelf,
/// never the language the app is being used in.
///
/// A closed list, for the reason genres are closed and one of its own: every
/// value is named in the reader's language, and an arbitrary ISO code has no
/// name the app can print. An edition
/// in a language the list does not carry keeps no language at all, rather than an
/// `other` that would be a second way of saying "unknown".
enum BookLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case fr, en, es, de, it, pt, nl, sv, pl, ru, uk, tr, ar, ja, zh, ko

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fr: String(localized: "Français")
        case .en: String(localized: "Anglais")
        case .es: String(localized: "Espagnol")
        case .de: String(localized: "Allemand")
        case .it: String(localized: "Italien")
        case .pt: String(localized: "Portugais")
        case .nl: String(localized: "Néerlandais")
        case .sv: String(localized: "Suédois")
        case .pl: String(localized: "Polonais")
        case .ru: String(localized: "Russe")
        case .uk: String(localized: "Ukrainien")
        case .tr: String(localized: "Turc")
        case .ar: String(localized: "Arabe")
        case .ja: String(localized: "Japonais")
        case .zh: String(localized: "Chinois")
        case .ko: String(localized: "Coréen")
        }
    }

    /// The language the phone is set to, when it is one this list draws. Nil
    /// when the phone speaks something the list does not: every edition is then
    /// foreign and every tag shows.
    static var device: BookLanguage? {
        Locale.current.language.languageCode.flatMap { BookLanguage(rawValue: $0.identifier) }
    }

    /// The language the app speaks, when it is one this list draws: the one it
    /// resolved from the phone among those it is translated into.
    static var app: BookLanguage? {
        Bundle.main.preferredLocalizations.first
            .map { Locale.Language(identifier: $0) }
            .flatMap(\.languageCode)
            .flatMap { BookLanguage(rawValue: $0.identifier) }
    }

    /// The editions a scan is checked against: the app's language, French and
    /// English. A reader's shelf holds the first, and the confusion a cover
    /// makes is with English, whose titles a translation often keeps —
    /// « Powerful » is printed on the French edition too.
    static var reviewChoices: [BookLanguage] {
        var choices = app.map { [$0] } ?? []
        for language in [BookLanguage.fr, .en] where !choices.contains(language) {
            choices.append(language)
        }
        return choices
    }

    /// The edition a scanned book is presumed in: the app's language, unless the
    /// cover plainly said another that the review does not offer — a Japanese
    /// manga reads as Japanese. A cover read as English is not trusted over the
    /// app, since a French edition keeping its English title reads the same,
    /// and an edition taken for the wrong language drew the other one's
    /// volumes on the saga screen. The review lets the reader switch.
    static func presumed(scanned: BookLanguage?) -> BookLanguage? {
        guard let scanned, !reviewChoices.contains(scanned) else { return app ?? scanned }
        return scanned
    }

    /// Whether a language tag is worth drawing. A reader whose phone is in French
    /// owns a French library by default, and an "FR" on every row says nothing;
    /// the tag marks the exception, the edition in another language. Which is why this
    /// compares to the phone, not to the reader's most common language: the
    /// phone is known before the library is loaded and never shifts as it grows.
    var isForeign: Bool { self != Self.device }

    /// The code drawn on the language tag: "EN", "JA". A code rather than a flag,
    /// because a language is not a country — English is not British, Spanish not
    /// Spanish — and a code is what a bookshop prints beside a foreign edition.
    var code: String { rawValue.uppercased() }
}
