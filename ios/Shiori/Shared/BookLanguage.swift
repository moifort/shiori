import Foundation

/// The language an edition is printed or recorded in — the object on the shelf,
/// never the language the app is being used in.
///
/// A closed list, for the reason genres are closed and one of its own: every
/// value draws a flag, and an arbitrary ISO code has no flag to draw. An edition
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
    /// foreign and every flag shows.
    static var device: BookLanguage? {
        Locale.current.language.languageCode.flatMap { BookLanguage(rawValue: $0.identifier) }
    }

    /// Whether a flag is worth drawing. A reader whose phone is in French owns a
    /// French library by default, and a 🇫🇷 on every row says nothing; the flag
    /// marks the exception, the edition in another language. Which is why this
    /// compares to the phone, not to the reader's most common language: the
    /// phone is known before the library is loaded and never shifts as it grows.
    var isForeign: Bool { self != Self.device }

    /// The flag a reader reads as "this one is the French edition". A language is
    /// not a country and several of these are spoken in many: the flag is a
    /// convenience for telling two shelves apart at a glance, not a claim about
    /// where the book was printed or who speaks the language.
    var flag: String {
        switch self {
        case .fr: "🇫🇷"
        case .en: "🇬🇧"
        case .es: "🇪🇸"
        case .de: "🇩🇪"
        case .it: "🇮🇹"
        case .pt: "🇵🇹"
        case .nl: "🇳🇱"
        case .sv: "🇸🇪"
        case .pl: "🇵🇱"
        case .ru: "🇷🇺"
        case .uk: "🇺🇦"
        case .tr: "🇹🇷"
        case .ar: "🇸🇦"
        case .ja: "🇯🇵"
        case .zh: "🇨🇳"
        case .ko: "🇰🇷"
        }
    }
}
