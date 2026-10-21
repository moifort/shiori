import CoreGraphics
import Testing
@testable import Shiori

struct HomeColumnsTests {
    @Test func aPhoneKeepsOneColumn() {
        #expect(HomeColumns(width: 440, fold: nil, minimum: 640) == nil)
    }

    @Test func aWideScreenWithNoFoldSplitsInTwoHalves() throws {
        let columns = try #require(HomeColumns(width: 830, fold: nil, minimum: 640))
        #expect(columns.leading == columns.trailing)
        #expect(columns.leading == 391) // (830 - 2 × 16 - 16) / 2
        #expect(columns.gutter == 16)
    }

    @Test func anOpenDuoCentresTheGutterOnTheFold() throws {
        // The page leaves the tab bar on its right: the fold is off its middle.
        let columns = try #require(HomeColumns(width: 830, fold: 475.5, minimum: 640))
        #expect(columns.gutter == 32)
        #expect(16 + columns.leading + columns.gutter / 2 == 475.5)
        #expect(16 + columns.leading + columns.gutter + columns.trailing + 16 == 830)
    }

    @Test func aFoldTooCloseToAnEdgeFallsBackToTwoHalves() throws {
        let columns = try #require(HomeColumns(width: 830, fold: 200, minimum: 640))
        #expect(columns.leading == columns.trailing)
        #expect(columns.gutter == 16)
    }
}
