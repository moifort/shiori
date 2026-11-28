import Testing
@testable import Shiori

struct OnboardingOrderTests {
    @Test func theFreeMonthComesBeforeTheLibraries() {
        #expect(OnboardingOrder.afterProfile(isPremium: false) == .trial)
        #expect(OnboardingOrder.afterProfile(isPremium: nil) == .trial)
    }

    @Test func aSubscribedAccountGoesStraightToTheLibraries() {
        #expect(OnboardingOrder.afterProfile(isPremium: true) == .libraries)
    }

    @Test func noSubscriptionStaysOnTheWallLibrariesOrNot() {
        #expect(OnboardingOrder.ready(requiresSubscription: true, librariesPending: true) == .wall)
        #expect(OnboardingOrder.ready(requiresSubscription: true, librariesPending: false) == .wall)
    }

    @Test func subscribingAfterLeavingOnTheWallLeadsToTheLibraries() {
        #expect(OnboardingOrder.ready(requiresSubscription: false, librariesPending: true) == .libraries)
        #expect(OnboardingOrder.ready(requiresSubscription: false, librariesPending: false) == .app)
    }
}
