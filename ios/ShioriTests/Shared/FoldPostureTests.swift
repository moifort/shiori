import SwiftUI
import Testing
@testable import Shiori

struct FoldPostureTests {
    private let inner = CGSize(width: 866, height: 669)
    private let margins = EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 12)

    @Test func laidFlatThePagesPartOnTheFoldLine() {
        let posture = FoldPosture(
            fold: CGRect(x: 475, y: 0, width: 0, height: 669), margins: margins, isActive: false, in: inner
        )

        #expect(posture == .flat(line: 475))
    }

    @Test func heldLikeABookThePagesKeepClearOfTheCreaseAndItsMargins() throws {
        let posture = FoldPosture(
            fold: CGRect(x: 465, y: 0, width: 20, height: 669), margins: margins, isActive: true, in: inner
        )
        let pages = try #require(posture.pages(in: inner))

        #expect(posture == .book(crease: 453...497))
        #expect(pages.first == CGRect(x: 0, y: 0, width: 453, height: 669))
        #expect(pages.second == CGRect(x: 497, y: 0, width: 369, height: 669))
    }

    @Test func standingLikeALaptopThePagesSitAboveAndBelowTheCrease() throws {
        let upright = CGSize(width: 669, height: 866)
        let posture = FoldPosture(
            fold: CGRect(x: 0, y: 423, width: 669, height: 20),
            margins: EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0),
            isActive: true,
            in: upright
        )
        let pages = try #require(posture.pages(in: upright))

        #expect(posture == .laptop(crease: 413...453))
        #expect(pages.first == CGRect(x: 0, y: 0, width: 669, height: 413))
        #expect(pages.second == CGRect(x: 0, y: 453, width: 669, height: 413))
    }

    @Test func aTallFlatScreenStaysOnePage() {
        let posture = FoldPosture(
            fold: CGRect(x: 0, y: 433, width: 669, height: 0),
            margins: EdgeInsets(),
            isActive: false,
            in: CGSize(width: 669, height: 866)
        )

        #expect(posture == .single)
    }

    @Test func aFoldBesideTheViewLeavesItOnePage() {
        // A detail column right of the crease: the fold sits outside it.
        let posture = FoldPosture(
            fold: CGRect(x: -20, y: 0, width: 20, height: 669), margins: margins, isActive: true,
            in: CGSize(width: 390, height: 669)
        )

        #expect(posture == .single)
        #expect(posture.pages(in: CGSize(width: 390, height: 669)) == nil)
    }

    @Test func onlyAPartlyFoldedDuoCountsAsFolded() {
        #expect(FoldPosture.book(crease: 1...2).isFolded)
        #expect(FoldPosture.laptop(crease: 1...2).isFolded)
        #expect(!FoldPosture.flat(line: 1).isFolded)
        #expect(!FoldPosture.single.isFolded)
    }
}
