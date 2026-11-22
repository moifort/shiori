import Foundation
import Testing
@testable import Shiori

@Suite("The sleep timer fades the listening out")
struct SleepTimerTests {
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    private func timer(_ minutes: Int = 15) -> SleepTimer {
        SleepTimer(minutes: minutes, from: start)
    }

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    @Test("ends as many minutes after it was set as it was set to")
    func endsAfterItsMinutes() {
        #expect(timer(15).endsAt == at(900))
        #expect(timer(30).endsAt == at(1800))
    }

    @Test("plays at full volume until the fade, which takes the last seconds")
    func fullVolumeBeforeTheFade() {
        #expect(SleepTimer.fadeDuration == 5)
        let timer = timer()
        #expect(timer.fadeStartsAt == at(900 - SleepTimer.fadeDuration))
        #expect(timer.volume(at: at(0)) == 1)
        #expect(timer.volume(at: at(600)) == 1)
        #expect(!timer.isFading(at: at(600)))
    }

    @Test("falls steadily to silence over the fade")
    func fallsToSilence() {
        let timer = timer()
        let fadeStart = 900 - SleepTimer.fadeDuration
        #expect(timer.isFading(at: at(fadeStart)))
        #expect(timer.volume(at: at(fadeStart)) == 1)
        let half = timer.volume(at: at(fadeStart + SleepTimer.fadeDuration / 2))
        #expect(half == 0.25)
        var previous: Float = 1
        for step in stride(from: fadeStart, through: 900, by: 1) {
            let volume = timer.volume(at: at(step))
            #expect(volume <= previous)
            previous = volume
        }
        #expect(timer.volume(at: at(900)) == 0)
    }

    @Test("is over once it ends: no more fade, the player pauses")
    func overAtTheEnd() {
        let timer = timer()
        #expect(!timer.isOver(at: at(899)))
        #expect(timer.isOver(at: at(900)))
        #expect(!timer.isFading(at: at(900)))
        #expect(timer.volume(at: at(1000)) == 0)
    }

    @Test("set again during the fade, it starts over at full volume")
    func restartedDuringTheFade() {
        let restarted = SleepTimer(minutes: 15, from: at(897))
        #expect(restarted.endsAt == at(1797))
        #expect(restarted.volume(at: at(897)) == 1)
        #expect(!restarted.isFading(at: at(897)))
    }
}

@MainActor
@Suite("A headset press restarts the sleep timer")
struct SleepTimerRestartTests {
    @Test("a running timer starts over for as long as it was set")
    func restartsARunningTimer() throws {
        let player = AudiblePlayer()
        player.toggleSleepTimer(minutes: 15)
        let first = try #require(player.sleepTimer)
        #expect(player.restartSleepTimer())
        let second = try #require(player.sleepTimer)
        #expect(second.minutes == 15)
        #expect(second.endsAt >= first.endsAt)
        #expect(!player.isSleepFading)
    }

    @Test("no timer set: a press does nothing to it")
    func noTimer() {
        let player = AudiblePlayer()
        #expect(!player.restartSleepTimer())
        #expect(player.sleepTimer == nil)
    }

    @Test("the same choice again turns the timer off")
    func toggledOff() {
        let player = AudiblePlayer()
        player.toggleSleepTimer(minutes: 20)
        player.toggleSleepTimer(minutes: 20)
        #expect(player.sleepTimer == nil)
        #expect(!player.restartSleepTimer())
    }
}
