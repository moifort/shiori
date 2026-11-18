import Apollo
import ApolloAPI
import Foundation

/// The Audible player's three calls. None changes the library: a licence, a
/// content key and a saved position are Audible's, not Shiori's.
enum ListeningAPI {
    static func start(asin: String) async throws -> Playback {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.StartAudiblePlaybackMutation(asin: asin),
            changesLibrary: false
        )
        let playback = data.startAudiblePlayback
        guard let streamURL = URL(string: playback.streamUrl),
              let certificate = Data(base64Encoded: playback.certificate)
        else { throw ListeningError.unreadableLicence }
        return Playback(
            asin: playback.asin,
            contentReference: playback.contentReference,
            streamURL: streamURL,
            certificate: certificate,
            duration: TimeInterval(playback.durationMs) / 1000,
            chapters: playback.chapters.map {
                ListeningChapter(
                    title: $0.title,
                    start: TimeInterval($0.startMs) / 1000,
                    length: TimeInterval($0.lengthMs) / 1000
                )
            },
            resumeAt: playback.position.map { TimeInterval($0.positionMs) / 1000 }
        )
    }

    static func contentKey(asin: String, request spc: Data) async throws -> Data {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AudibleFairPlayKeyMutation(
                asin: asin,
                spc: spc.base64EncodedString()
            ),
            changesLibrary: false
        )
        guard let ckc = Data(base64Encoded: data.audibleFairPlayKey) else {
            throw ListeningError.unreadableKey
        }
        return ckc
    }

    static func savePosition(asin: String, contentReference: String, at position: TimeInterval) async throws {
        _ = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.SaveAudiblePositionMutation(
                asin: asin,
                contentReference: contentReference,
                positionMs: Int32(clamping: Int(max(0, position) * 1000))
            ),
            changesLibrary: false
        )
    }
}

enum ListeningError: Error {
    case unreadableLicence
    case unreadableKey
}
