import CoreGraphics
import Testing
@testable import Shiori

struct MosaicColumnsTests {
    @Test func withoutAFoldTheColumnsFillTheWidth() {
        let layout = MosaicColumns(width: 698, columns: 7, spacing: 2, fold: nil)

        #expect(layout.count == 7)
        #expect(layout.tileWidth == 98)
        #expect(layout.leading == 0)
        #expect(layout.columnsBeforeFold == nil)
    }

    @Test func theCreaseRunsDownTheMiddleOfAGapBetweenCovers() throws {
        // Partly folded: the crease and its margins, off centre since the
        // vertical bar takes the right edge.
        let layout = MosaicColumns(width: 866, columns: 7, spacing: 2, fold: 455...495)

        let before = try #require(layout.columnsBeforeFold)
        let gapCentre = layout.leading + CGFloat(before) * (layout.tileWidth + 2) - 1
        #expect(abs(gapCentre - 475) < 0.001)
    }

    @Test func theMosaicStillFillsThePage() {
        let layout = MosaicColumns(width: 866, columns: 7, spacing: 2, fold: 455...495)

        #expect((6...8).contains(layout.count))
        #expect(layout.leading >= 0)
        #expect(layout.leading + layout.gridWidth <= 866)
        // What is left over at the edges stays well under a cover's width.
        #expect(866 - layout.gridWidth < layout.tileWidth / 2)
    }

    @Test func aFoldOutsideTheGridChangesNothing() {
        let layout = MosaicColumns(width: 420, columns: 7, spacing: 2, fold: 600...640)

        #expect(layout.count == 7)
        #expect(layout.columnsBeforeFold == nil)
    }
}
