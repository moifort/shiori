import SwiftUI

extension Book {
    /// What the book is, as the reader's own page sets its tiles, without the
    /// taps that correct them: for a page that shows a book the reader cannot
    /// change — a friend's, a discovery.
    var readOnlyFactTiles: [FactTile] {
        var tiles = [
            FactTile(id: "genre", title: "Genre", value: genre?.label, chips: subgenres, isWide: true),
            FactTile(id: "format", title: "Format", value: formatFactValue),
            FactTile(id: "publisher", title: "Éditeur", value: publisher),
            FactTile(id: "firstPublishedIn", title: "Parution", value: firstPublishedIn.map(String.init)),
        ]
        if let duration = durationLabel {
            tiles.append(FactTile(id: "duration", title: "Durée", value: duration))
        } else {
            tiles.append(FactTile(id: "pageCount", title: "Pages", value: pageCount.map(String.init)))
        }
        if BookFact.editionYear.applies(to: self), let editionYear {
            tiles.append(FactTile(id: "editionYear", title: "Année d'édition", value: String(editionYear)))
        }
        if format != .audiobook {
            tiles.append(FactTile(
                id: "isbn13",
                title: "ISBN",
                value: isbn13,
                valueFont: .subheadline.weight(.semibold).monospacedDigit()
            ))
        }
        return tiles
    }

    /// What the book is and how it is held, in one tile: "Livre · papier",
    /// "Manga · papier et numérique", "Livre audio".
    var formatFactValue: String {
        guard format != .audiobook, !media.isEmpty else { return format.label }
        return "\(format.label) · \(BookMedium.label(of: media).lowercased())"
    }

    /// Ways out of Shiori, closing the facts they complete.
    var storeFactLinks: [FactLink] {
        [
            audibleURL.map { FactLink(id: "audible", title: "Écouter sur Audible", logo: "audible-logo", url: $0) },
            amazonURL.map { FactLink(id: "amazon", title: "Voir sur Amazon", logo: "amazon-logo", url: $0) },
        ].compactMap { $0 }
    }
}
