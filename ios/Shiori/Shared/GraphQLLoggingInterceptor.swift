import Apollo
import ApolloAPI
import Foundation
import OSLog

private let log = Logger(subsystem: "com.polyforms.shiori.app", category: "graphql")

/// Logs any GraphQL errors returned for an operation. Post-flight work happens in
/// the `.map` of the result stream (Apollo 2.x interceptor model).
struct GraphQLLoggingInterceptor: GraphQLInterceptor {
    func intercept<Request: GraphQLRequest>(
        request: Request,
        next: NextInterceptorFunction<Request>
    ) async throws -> InterceptorResultStream<Request> {
        await next(request).map { parsed in
            if let errors = parsed.result.errors, !errors.isEmpty {
                for error in errors {
                    let code = (error.extensions?["code"] as? String) ?? "<no code>"
                    let message = error.message ?? "<no message>"
                    log.error(
                        "\(Request.Operation.operationName, privacy: .public) [\(code, privacy: .public)] \(message, privacy: .public)"
                    )
                }
            }
            return parsed
        }
    }
}
