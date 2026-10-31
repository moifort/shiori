import Foundation

/// What the onboarding asks of the server and of the background passes, as
/// closures: `.live` goes through the APIs, a test or a preview builds its own.
struct OnboardingClient: Sendable {
    /// Saves the first name and grants the welcome scans.
    var complete: @Sendable (_ firstName: String) async throws -> Void
    /// Keeps the avatar the reader chose, and answers what the server keeps.
    var changeAvatar: @Sendable (AccountAvatar) async throws -> AccountAvatar
    var startSignIn: @Sendable (ImportSource, AmazonMarketplace) async throws -> AmazonLogin
    /// Links the library with Amazon's code, and starts its pass in the background.
    var completeSignIn: @Sendable (ImportSource, _ code: String) async throws -> Void
    /// The preparation screen drawn until the library is ready, told which
    /// libraries were linked.
    var beginPreparation: @Sendable @MainActor ([ImportSource]) -> Void
}

extension OnboardingClient {
    static let live = OnboardingClient(
        complete: { try await OnboardingAPI.completeOnboarding(firstName: $0) },
        changeAvatar: { try await OnboardingAPI.changeAvatar($0) },
        startSignIn: { source, marketplace in
            switch source {
            case .audible: try await ImportAPI.startSignIn(on: marketplace)
            case .kindle: try await KindleAPI.startSignIn(on: marketplace)
            }
        },
        completeSignIn: { source, code in
            switch source {
            case .audible:
                _ = try await ImportAPI.completeSignIn(authorizationCode: code)
                await AudibleBackgroundSync.shared.start()
            case .kindle:
                _ = try await KindleAPI.completeSignIn(authorizationCode: code)
                await KindleBackgroundSync.shared.start()
            }
        },
        beginPreparation: { LibraryPreparation.shared.begin(linking: $0) }
    )

    /// Accepts everything and starts nothing.
    static let preview = OnboardingClient(
        complete: { _ in },
        changeAvatar: { $0 },
        startSignIn: { _, _ in throw CancellationError() },
        completeSignIn: { _, _ in },
        beginPreparation: { _ in }
    )
}
