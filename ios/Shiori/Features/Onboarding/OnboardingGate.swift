import Observation

/// Decides, once a Firebase user is signed in, whether to show the onboarding
/// wizard or the main app. Reads `me` at launch; `onboardingCompleted` drives the
/// choice. Lives at `AuthRoot` scope and is refreshed on sign-in / account switch.
@MainActor
@Observable
final class OnboardingGate {
    enum State: Equatable {
        case loading
        case required
        case ready
        case failed(String)
    }

    private(set) var state: State = .loading
    /// Whether the signed-in account may see the admin surfaces. Rides the same
    /// launch `me` query, so non-admins cost no extra call: the banner and the
    /// settings row are simply absent for them.
    private(set) var isAdmin = false

    func refresh() async {
        state = .loading
        do {
            let me = try await OnboardingAPI.loadMe()
            isAdmin = me.isAdmin
            state = me.onboardingCompleted ? .ready : .required
        } catch {
            state = .failed(reportError(error))
        }
    }

    /// Called by the wizard on success to enter the app without a re-fetch.
    func markCompleted() {
        state = .ready
    }

    /// Clear the resolved state on sign-out so a different account signing in next
    /// never sees the previous user's state for a frame before `refresh()` runs.
    func reset() {
        state = .loading
        isAdmin = false
    }
}
