import Testing
@testable import Shiori

struct SeriesFollowButtonTests {
    @Test func followedSagaShowsAnOpenEye() {
        #expect(SeriesPage.followSymbol(isFollowed: true) == "eye")
    }

    @Test func sagaSetAsideShowsTheCrossedOutEyeOfItsFilter() {
        #expect(SeriesPage.followSymbol(isFollowed: false) == "eye.slash")
        #expect(SeriesPage.followSymbol(isFollowed: false) == SeriesState.unfollowed.symbol)
    }

    @Test func theTwoStatesNeverShareASymbol() {
        #expect(SeriesPage.followSymbol(isFollowed: true) != SeriesPage.followSymbol(isFollowed: false))
    }
}
