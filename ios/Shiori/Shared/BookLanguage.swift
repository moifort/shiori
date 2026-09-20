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
