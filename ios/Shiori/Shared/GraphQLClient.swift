import Apollo
import ApolloAPI
import Foundation

/// Singleton ApolloClient configured for the Firebase Functions /graphql endpoint.
/// Each request goes through:
///   1. GraphQL interceptors — Apollo defaults + GraphQLLoggingInterceptor (logs errors)
///   2. HTTP interceptors — FirebaseTokenInterceptor (injects Authorization: Bearer <ID Token>)
///      then Apollo's ResponseCodeInterceptor
final class GraphQLClient: @unchecked Sendable {
    static let shared = GraphQLClient()

    // Built once: recreating the store/transport per request would discard
    // connection reuse. The base URL is read at init — changing the server URL
    // in the debug settings requires an app restart.
    let apollo: ApolloClient

    private init() {
        let url = APIClient.shared.baseURL.appendingPathComponent("graphql")
        let store = ApolloStore()
        let transport = RequestChainNetworkTransport(
            urlSession: URLSession(configuration: .default),
            interceptorProvider: AuthenticatedInterceptorProvider(),
            store: store,
            endpointURL: url
        )
        apollo = ApolloClient(networkTransport: transport, store: store)
    }
}

/// Adds our Firebase auth (HTTP) and error logging (GraphQL) interceptors on top
/// of Apollo's default chain. Apollo 2.x makes `DefaultInterceptorProvider` final,
/// so we conform to `InterceptorProvider` directly and re-list the defaults.
struct AuthenticatedInterceptorProvider: InterceptorProvider {
    func graphQLInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any GraphQLInterceptor] {
        [
            MaxRetryInterceptor(),
            AutomaticPersistedQueryInterceptor(),
            GraphQLLoggingInterceptor(),
        ]
    }

    func httpInterceptors<Operation: GraphQLOperation>(
        for operation: Operation
    ) -> [any HTTPInterceptor] {
        [
            FirebaseTokenInterceptor(),
            AcceptLanguageInterceptor(),
            ResponseCodeInterceptor(),
        ]
    }
}
