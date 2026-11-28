import Foundation
import Testing
@testable import Shiori

@Suite("When a sent position tells the library")
struct ListeningLibraryNoticeTests {
    private let hours10: TimeInterval = 10 * 3600

    @Test("the save sent as the title starts announces the book under way, once")
    func firstSaveOnce() {
        var notice = ListeningLibraryNotice()
        let a1 = notice.shouldAnnounce(asin: "B1", position: 0, duration: hours10, periodic: false)
        #expect(a1)
        let a2 = notice.shouldAnnounce(asin: "B1", position: 30, duration: hours10, periodic: true)
        #expect(!a2)
        let a3 = notice.shouldAnnounce(asin: "B1", position: 60, duration: hours10, periodic: true)
        #expect(!a3)
    }

    @Test("a pause announces the progress, however early")
    func pauseAnnounces() {
        var notice = ListeningLibraryNotice()
        _ = notice.shouldAnnounce(asin: "B1", position: 0, duration: hours10, periodic: false)
        let a4 = notice.shouldAnnounce(asin: "B1", position: 5, duration: hours10, periodic: false)
        #expect(a4)
        let a5 = notice.shouldAnnounce(asin: "B1", position: 600, duration: hours10, periodic: false)
        #expect(a5)
    }

    @Test("the end of the book is always announced")
    func endAnnounces() {
        var notice = ListeningLibraryNotice()
        _ = notice.shouldAnnounce(asin: "B1", position: 0, duration: hours10, periodic: false)
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
