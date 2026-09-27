import Apollo
import FirebaseAuth
import Foundation

/// Injects the current Firebase user's ID token into every GraphQL request as
/// `Authorization: Bearer <token>`. Firebase Auth refreshes the token under the
/// hood so this is always fresh. Runs at the HTTP layer (Apollo 2.x) where the
/// request is a plain `URLRequest`.
///
/// A refused token is where a dead session shows: when the account behind it
/// is gone, the reader is signed out rather than left on screens that can no
/// longer load.
struct FirebaseTokenInterceptor: HTTPInterceptor {
    func intercept(
        request: URLRequest,
        next: NextHTTPInterceptorFunction
    ) async throws -> HTTPResponse {
        var request = request
        if let currentUser = Auth.auth().currentUser {
            do {
                let token = try await currentUser.idToken()
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } catch {
                await AuthSession.dropSessionIfAccountIsGone()
                throw error
            }
        }
        let response = try await next(request)
        if response.response.statusCode == 401 {
            await AuthSession.dropSessionIfAccountIsGone()
        }
        return response
    }
}

private extension User {
    /// Async wrapper around Firebase's callback-based ID token fetch.
    func idToken() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            getIDToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: token ?? "")
                }
            }
        }
    }
}
