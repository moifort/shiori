import SwiftUI

/// The entries of a menu sharing the favourites: the system sheet, for a mail
/// or a message, and a copy of its own, since the sheet does not always offer
/// one for plain text.
struct FavoritesShareItems: View {
    let text: String

    var body: some View {
        ShareLink(
            item: text,
            subject: Text("Mes favoris"),
            preview: SharePreview(Text("Mes favoris"))
        ) {
            Label("Envoyer…", systemImage: "paperplane")
        }
        Button {
            UIPasteboard.general.string = text
        } label: {
            Label("Copier la liste", systemImage: "doc.on.doc")
        }
        .accessibilityIdentifier("my-shelf-copy-favorites")
    }
}

#Preview {
    Menu("Partager mes favoris") {
        FavoritesShareItems(text: "• Dune — Frank Herbert — Space opera")
    }
}
