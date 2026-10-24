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

/// The same summary outside a list, on a page laid out as a hero and blocks:
/// four lines, then "Plus" unfolds the rest, as the TV app folds a film's
/// pitch. The whole text is what is copied.
struct BookSynopsisBlock: View {
    let synopsis: String
    @State private var expanded = false
    @State private var isTruncated = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(synopsis)
                .font(.callout)
                .lineLimit(expanded ? nil : 4)
                .fixedSize(horizontal: false, vertical: true)
                .background {
                    // The whole text measured against the folded one: "Plus"
                    // only where there is more.
                    Text(synopsis)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { full in
                            isTruncated = full > Self.foldedHeight + 1
                        }
                }
                .copyable(synopsis)
            if isTruncated {
                Button(expanded ? "Moins" : "Plus") {
                    withAnimation(.snappy) { expanded.toggle() }
                }
                .font(.footnote.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .buttonStyle(.plain)
                .accessibilityIdentifier("book-summary-toggle")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Four lines of callout text.
    private static var foldedHeight: CGFloat {
        UIFont.preferredFont(forTextStyle: .callout).lineHeight * 4
    }
}

#Preview {
    List {
        BookSynopsisSection(synopsis: "Kvothe raconte sa propre légende, de la troupe de comédiens où il a grandi à l'Université.")
    }
}

#Preview("Block") {
    BookSynopsisBlock(synopsis: Book.preview.synopsis! + " " + Book.preview.synopsis! + " " + Book.preview.synopsis!)
        .padding()
}
