import CoreGraphics
import Testing
@testable import Shiori

struct MosaicColumnsTests {
    @Test func withoutAFoldTheColumnsFillTheWidth() {
        let layout = MosaicColumns(width: 698, columns: 7, spacing: 2, fold: nil)

        #expect(layout.count == 7)
        #expect(layout.tileWidth == 98)
        #expect(layout.leading == 0)
        #expect(layout.foldGap == nil)
    }

    @Test func aFoldAsksForAnEvenCount() {
        let layout = MosaicColumns(width: 800, columns: 7, spacing: 2, fold: 400...400)

        #expect(layout.count == 8)
    }

    @Test func noColumnStraddlesTheFold() {
        // Partly folded: the crease and its margins, off centre since the
        // vertical bar takes the right edge.
        let fold: ClosedRange<CGFloat> = 455...495
        let layout = MosaicColumns(width: 866, columns: 7, spacing: 2, fold: fold)

        let half = layout.count / 2
        let halfWidth = CGFloat(half) * layout.tileWidth + CGFloat(half - 1) * 2
        // The left half ends on the fold, the right half starts after it.
        #expect(layout.leading + halfWidth == fold.lowerBound)
        #expect(layout.foldGap == fold.upperBound - fold.lowerBound)
        #expect(fold.upperBound + halfWidth <= 866)
        #expect(layout.leading >= 0)
    }

    @Test func aFoldOutsideTheGridChangesNothing() {
        let layout = MosaicColumns(width: 420, columns: 7, spacing: 2, fold: 600...640)

        #expect(layout.count == 7)
        #expect(layout.foldGap == nil)
    }
}
