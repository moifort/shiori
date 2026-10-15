import SwiftUI

/// Where a book stands for the reader when the page is not their own copy: a
/// volume still to come, one just out, a friend's book they hold already, one
/// they just added. Said in its colour under the author.
struct BookState: Equatable {
    let text: String
    let tint: Color

    /// Out on `date` or coming then: orange while announced, green once out,
    /// grey with no date yet.
    static func release(_ date: String?) -> BookState {
        guard let date else {
            return BookState(text: String(localized: "Annoncé"), tint: .gray)
        }
        return ReleaseDateText.isUpcoming(date)
            ? BookState(text: ReleaseDateText.coming(date), tint: .orange)
            : BookState(text: ReleaseDateText.out(date), tint: .green)
    }

    /// A book on the pile whose edition is not out yet: grey, as a volume
    /// with no date is on the saga screen.
    static let forthcoming = BookState(text: String(localized: "Pas encore paru"), tint: .gray)

    static let owned = BookState(text: String(localized: "Déjà dans votre bibliothèque"), tint: .green)
    static let addedToPile = BookState(text: String(localized: "Ajouté à votre pile à lire"), tint: .green)
    static let addedAsRead = BookState(text: String(localized: "Ajouté à vos livres lus"), tint: .green)
}
