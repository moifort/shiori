import SwiftUI

extension BookGenre {
    /// One symbol per genre, outlined like the rest of the app's vocabulary.
    /// Nineteen are SF Symbols; SF has no rocket, ghost or feather, so those
    /// three live in the asset catalog, drawn on Apple's symbol template by
    /// `ios/tools/generate-symbols.swift`. Draw with `image` rather than
    /// `Image(systemName:)` so both kinds resolve.
    var symbol: String {
        switch self {
        case .fantasy: "wand.and.sparkles"
        case .scienceFiction: "rocket"
        case .horror: "ghost"
        case .crime: "magnifyingglass"
        case .thriller: "waveform.path.ecg"
        case .romance: "heart"
        case .historicalFiction: "scroll"
        case .adventure: "map"
        case .literaryFiction: "quote.opening"
        case .humor: "face.smiling"
        case .poetry: "feather"
        case .drama: "theatermasks"
        case .biography: "person.text.rectangle"
        case .history: "building.columns"
        case .essay: "lightbulb"
        case .science: "atom"
        case .selfHelp: "figure.mind.and.body"
        case .business: "chart.line.uptrend.xyaxis"
        case .art: "paintpalette"
        case .cooking: "frying.pan"
        case .travel: "airplane"
        case .other: "tag"
        }
    }

    /// Whether `symbol` names a custom symbol of the asset catalog rather than
    /// an SF Symbol.
    var hasCustomSymbol: Bool {
        switch self {
        case .scienceFiction, .horror, .poetry: true
        default: false
        }
    }

    var image: Image {
        hasCustomSymbol ? Image(symbol) : Image(systemName: symbol)
    }

    /// The colour the genre is drawn in where a list has room for a touch of
    /// it — the chips under a library row. Picked for the genre rather than
    /// derived from its name: fantasy is purple and romance is pink in every
    /// bookshop, and a hash would put horror in mint.
    ///
    /// Yellow is left out on purpose: it is the colour of the stars, and it
    /// has no contrast against a pale chip. Twenty-two genres are more than
    /// the palette holds, so distant ones share a colour — no reader reads a
    /// chip's hue as its genre, they read the word.
    var tint: Color {
        switch self {
        case .fantasy: .purple
        case .scienceFiction: .indigo
        case .horror: .red
        case .crime: .brown
        case .thriller: .orange
        case .romance: .pink
        case .historicalFiction: .brown
        case .adventure: .green
        case .literaryFiction: .teal
        case .humor: .orange
        case .poetry: .mint
        case .drama: .purple
        case .biography: .blue
        case .history: .brown
        case .essay: .cyan
        case .science: .blue
        case .selfHelp: .mint
        case .business: .green
        case .art: .pink
        case .cooking: .orange
        case .travel: .teal
        case .other: .gray
        }
    }
}

#Preview("Genres") {
    List(BookGenre.allCases) { genre in
        Label { Text(genre.label) } icon: { genre.image }
    }
}
