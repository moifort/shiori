import Apollo
import Foundation

/// Sends the device's preferred language as `Accept-Language` on every GraphQL
/// request. The backend uses it to write AI scan results in the user's language
/// (and to partition the scan cache per language). Runs at the HTTP layer where
/// the request is a plain `URLRequest`.
struct AcceptLanguageInterceptor: HTTPInterceptor {
    func intercept(
        request: URLRequest,
        next: NextHTTPInterceptorFunction
    ) async throws -> HTTPResponse {
        var request = request
        if let preferred = Locale.preferredLanguages.first {
            request.setValue(preferred, forHTTPHeaderField: "Accept-Language")
        }
        return try await next(request)
    }
}
