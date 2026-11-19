import SwiftUI

/// What may be awaited of a book the reader does not hold, and what is: its
/// translation and its recording in the app's language, each watched for and
/// announced the day it is out.
struct EditionWatch: Equatable, Sendable {
    /// Every edition the page offers to await, awaited or not, translation
    /// first.
    var offered: [ReleaseFormat]
    var awaited: Set<ReleaseFormat>

    init(offered: [ReleaseFormat], awaited: Set<ReleaseFormat>) {
        self.offered = ReleaseFormat.allCases.filter { offered.contains($0) || awaited.contains($0) }
        self.awaited = awaited
    }

    /// Nothing to await and nothing awaited.
    var isEmpty: Bool { offered.isEmpty }
}

extension ReleaseFormat {
    /// The edition as a menu names it.
    var watchTitle: LocalizedStringKey {
        switch self {
        case .book: "La traduction"
        case .audiobook: "L'audio"
        }
    }

    /// Its icon there.
    var watchSymbol: String {
        switch self {
        case .book: "binoculars"
        case .audiobook: "headphones"
        }
    }

    /// Its icon once awaited: the binoculars filled; the
    /// headphones have no filled form.
    var awaitedSymbol: String {
        switch self {
        case .book: "binoculars.fill"
        case .audiobook: "headphones"
        }
    }
}
