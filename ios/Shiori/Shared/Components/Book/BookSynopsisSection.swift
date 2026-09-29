import SwiftUI

/// A book's summary, on every page that shows one: folded past a few hundred
/// words — an Audible blurb can run to a screenful, and pushed what follows out
/// of reach — with a button to unfold it.
struct BookSynopsisSection: View {
    let synopsis: String
    @State private var expanded = false

    static let wordLimit = 120

    var body: some View {
        let words = synopsis.split(whereSeparator: \.isWhitespace)
        let folded = words.count > Self.wordLimit && !expanded
        Section("Résumé") {
            // The whole summary, folded or not: what is copied is the text,
            // not the part of it on screen.
            Text(folded ? words.prefix(Self.wordLimit).joined(separator: " ") + "…" : synopsis)
                .font(.callout)
                .copyable(synopsis)
            if words.count > Self.wordLimit {
                Button(folded ? "Lire la suite" : "Réduire") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.callout)
                .accessibilityIdentifier("book-summary-toggle")
            }
        }
    }
}
