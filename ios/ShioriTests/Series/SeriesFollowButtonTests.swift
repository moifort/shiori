import Testing
@testable import Shiori

struct SeriesFollowButtonTests {
    @Test func followedSagaShowsTheBell() {
        #expect(SeriesPage.followSymbol(isFollowed: true) == "bell")
    }

    @Test func sagaSetAsideShowsTheCrossedOutBellOfItsFilter() {
        #expect(SeriesPage.followSymbol(isFollowed: false) == "bell.slash")
        #expect(SeriesPage.followSymbol(isFollowed: false) == SeriesState.unfollowed.symbol)
    }

    @Test func theTwoStatesNeverShareASymbol() {
        #expect(SeriesPage.followSymbol(isFollowed: true) != SeriesPage.followSymbol(isFollowed: false))
    }
}
