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
}

#Preview("Genres") {
    List(BookGenre.allCases) { genre in
        Label { Text(genre.label) } icon: { genre.image }
    }
}
