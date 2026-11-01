import SwiftUI

/// What each of the year's tiles is called, drawn with, and says when empty.
extension YearRecap.Kind {
    /// The tile's label, small caps over its count.
    var title: LocalizedStringKey {
        switch self {
        case .awards: "Prix"
        case .friendsFavourites: "Favoris d'amis"
        case .seriesReleases: "Séries"
        case .awaitedAvailable: "Guettés"
        }
    }

    /// The same icons the rest of the app uses for these things.
    var systemImage: String {
        switch self {
        case .awards: "trophy"
        case .friendsFavourites: "heart.fill"
        case .seriesReleases: "books.vertical"
        case .awaitedAvailable: "binoculars"
        }
    }

    /// What an empty tile says.
    var emptyTitle: LocalizedStringKey {
        switch self {
        case .awards: "Aucun prix"
        case .friendsFavourites: "Aucun favori d'amis"
        case .seriesReleases: "Aucune sortie"
        case .awaitedAvailable: "Aucun livre guetté"
        }
    }

    /// The deep colours an empty tile's ground is made of: the two ends of its
    /// diagonal, then two lighter spots blurred into it.
    var palette: (from: Color, to: Color, spotLow: Color, spotHigh: Color) {
        switch self {
        case .awards: (Color(rgb: 0xD9922E), Color(rgb: 0x9C3F2B), Color(rgb: 0xE0A24A), Color(rgb: 0xB4532F))
        case .friendsFavourites: (Color(rgb: 0xC7487E), Color(rgb: 0x5B3A9E), Color(rgb: 0xD26A98), Color(rgb: 0x7A55B8))
        case .seriesReleases: (Color(rgb: 0x3569C9), Color(rgb: 0x1F8C9B), Color(rgb: 0x5A8BDB), Color(rgb: 0x34A5B3))
        case .awaitedAvailable: (Color(rgb: 0x1F9E73), Color(rgb: 0x5C9A3A), Color(rgb: 0x37B58A), Color(rgb: 0x7DB04E))
        }
    }
}

private extension Color {
    init(rgb: UInt32) {
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}
