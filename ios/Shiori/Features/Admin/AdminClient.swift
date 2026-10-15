import Foundation

/// What the admin screen asks of the server.
struct AdminClient: Sendable {
    var metrics: @Sendable () async throws -> AdminMetrics
}

extension AdminClient {
    static let live = AdminClient(metrics: { try await AdminAPI.metrics() })
}
