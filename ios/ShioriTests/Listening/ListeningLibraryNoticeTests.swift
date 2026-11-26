import Foundation
import Testing
@testable import Shiori

@Suite("When a sent position tells the library")
struct ListeningLibraryNoticeTests {
    private let hours10: TimeInterval = 10 * 3600

    @Test("the first save past a minute announces the book under way, once")
    func firstMinuteOnce() {
        var notice = ListeningLibraryNotice()
        let a1 = notice.shouldAnnounce(asin: "B1", position: 30, duration: hours10, periodic: true)
        #expect(!a1)
        let a2 = notice.shouldAnnounce(asin: "B1", position: 60, duration: hours10, periodic: true)
        #expect(a2)
        let a3 = notice.shouldAnnounce(asin: "B1", position: 90, duration: hours10, periodic: true)
        #expect(!a3)
    }

    @Test("a pause announces the progress, a wrong tap does not")
    func pauseAnnounces() {
        var notice = ListeningLibraryNotice()
        let a4 = notice.shouldAnnounce(asin: "B1", position: 10, duration: hours10, periodic: false)
        #expect(!a4)
        _ = notice.shouldAnnounce(asin: "B1", position: 60, duration: hours10, periodic: true)
        let a5 = notice.shouldAnnounce(asin: "B1", position: 600, duration: hours10, periodic: false)
        #expect(a5)
    }

    @Test("the end of the book is always announced")
    func endAnnounces() {
        var notice = ListeningLibraryNotice()
        _ = notice.shouldAnnounce(asin: "B1", position: 60, duration: hours10, periodic: true)
        let a6 = notice.shouldAnnounce(asin: "B1", position: hours10 - 60, duration: hours10, periodic: true)
        #expect(a6)
    }

    @Test("each title is announced on its own")
    func perTitle() {
        var notice = ListeningLibraryNotice()
        let a7 = notice.shouldAnnounce(asin: "B1", position: 120, duration: hours10, periodic: true)
        #expect(a7)
        let a8 = notice.shouldAnnounce(asin: "B2", position: 120, duration: hours10, periodic: true)
        #expect(a8)
    }
}
