import Testing
@testable import Shiori

struct OnboardingLibraryStepsTests {
    @Test func stepsFollowThePageOrderWhateverTheTickingOrder() {
        let steps = OnboardingLibrarySteps(chosen: [.goodreads, .audible])
        #expect(steps.chosen == [.audible, .goodreads])
        #expect(steps.current == .audible)
        #expect(steps.next == .goodreads)
        #expect(steps.number == 1)
        #expect(steps.count == 2)
    }

    @Test func eachLibraryIsConnectedOrSkippedBeforeTheNext() {
        var steps = OnboardingLibrarySteps(chosen: Set(OnboardingLibrary.allCases))
        steps.connected()
        #expect(steps.phase == .connected)
        steps.advance()
        #expect(steps.current == .kindle)
        #expect(steps.phase == .intro)
        #expect(steps.number == 2)
        steps.failed()
        steps.retry()
        #expect(steps.phase == .intro)
        steps.advance()
        #expect(steps.current == .goodreads)
        #expect(steps.next == nil)
        steps.advance()
        #expect(steps.isFinished)
    }

    @Test func nothingTickedIsFinishedAtOnce() {
        #expect(OnboardingLibrarySteps(chosen: []).isFinished)
    }
}
