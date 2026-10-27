import Testing
import UIKit
@testable import Shiori

/// The genres' symbols, which a typo would draw as nothing.
struct GenreSymbolTests {
    @Test(arguments: BookGenre.allCases)
    func everyGenreHasASymbolToDraw(_ genre: BookGenre) {
        let image = genre.hasCustomSymbol
            ? UIImage(named: genre.symbol)
            : UIImage(systemName: genre.symbol)
        #expect(image != nil, "\(genre.symbol)")
    }
}
