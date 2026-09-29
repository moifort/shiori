import SwiftUI

/// Where a book stands for the reader when the page is not their own copy: a
/// volume still to come, one just out, a friend's book they hold already, one
/// they just added. Said twice, as a bookshop sticker and its label: a round
/// glyph pinned on the cover's foot, and the words in its colour under the
/// author.
struct BookState: Equatable {
    let text: String
    let systemImage: String
    let tint: Color

    /// Out on `date` or coming then: orange while announced, green once out,
    /// grey with no date yet.
    static func release(_ date: String?) -> BookState {
        guard let date else {
            return BookState(text: String(localized: "Annoncé"), systemImage: "clock", tint: .gray)
        }
        return ReleaseDateText.isUpcoming(date)
            ? BookState(text: ReleaseDateText.coming(date), systemImage: "clock", tint: .orange)
            : BookState(text: ReleaseDateText.out(date), systemImage: "checkmark", tint: .green)
    }

    static let owned = BookState(
        text: String(localized: "Déjà dans votre bibliothèque"),
        systemImage: "checkmark",
        tint: .green
    )

    static let addedToPile = BookState(
        text: String(localized: "Ajouté à votre pile à lire"),
        systemImage: "plus",
        tint: .green
    )

    static let addedAsRead = BookState(
        text: String(localized: "Ajouté à vos livres lus"),
        systemImage: "plus",
        tint: .green
    )
}

/// The glyph a `BookState` pins on a cover: a disc in the state's colour, as
/// the headphones pill is pinned on a recording's.
struct BookStateBadge: View {
    let state: BookState
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: state.systemImage)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(state.tint, in: Circle())
            .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 1.5))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        BookStateBadge(state: .release("2026-11-05"))
        BookStateBadge(state: .release("2026-09-10"))
        BookStateBadge(state: .release(nil))
        BookStateBadge(state: .owned)
        BookStateBadge(state: .addedToPile)
    }
    .padding()
}
