import CoreGraphics
import Testing
@testable import Shiori

struct HomeColumnsTests {
    @Test func aPhoneKeepsOneColumn() {
        #expect(HomeColumns(width: 440, fold: nil, isRegularWidth: false) == nil)
    }

    @Test func aRegularWidthTooNarrowForTwoColumnsKeepsOne() {
        #expect(HomeColumns(width: 500, fold: nil, isRegularWidth: true) == nil)
    }

    @Test func aWideScreenWithNoFoldSplitsInTwoHalves() throws {
        let columns = try #require(HomeColumns(width: 830, fold: nil, isRegularWidth: true))
        #expect(columns.leading == columns.trailing)
        #expect(columns.leading == 391) // (830 - 2 × 16 - 16) / 2
        #expect(columns.gutter == 16)
    }

    @Test func anOpenDuoKeepsTheGutterOverTheFold() throws {
        // The page leaves the tab bar on its right: the fold is off its middle.
        let columns = try #require(HomeColumns(width: 830, fold: 470...480, isRegularWidth: true))
        #expect(columns.leading == 438) // 470 - 16 clear of the fold - 16 margin
        #expect(columns.gutter == 42) // the 10-point fold and 16 clear on each side
        #expect(16 + columns.leading + columns.gutter + columns.trailing + 16 == 830)
    }

    @Test func aFoldTooCloseToAnEdgeFallsBackToTwoHalves() throws {
        let columns = try #require(HomeColumns(width: 830, fold: 200...200, isRegularWidth: true))
        #expect(columns.leading == columns.trailing)
        #expect(columns.gutter == 16)
    }
}
