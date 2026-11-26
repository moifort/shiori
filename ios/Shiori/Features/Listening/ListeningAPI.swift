import Apollo
import ApolloAPI
import Foundation

/// The Audible player's three calls. A licence and a content key are
/// Audible's; a saved position also moves the book on the server (under way,
/// progress, read at the end), which the player announces itself, sparingly
/// (`ListeningLibraryNotice`), rather than at every save.
enum ListeningAPI {
    /// A licence for one title. `offline` asks for a download licence, whose
    /// key the iPhone may keep: the title then plays with no network.
    static func start(asin: String, offline: Bool) async throws -> Playback {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.StartAudiblePlaybackMutation(asin: asin, offline: .some(offline)),
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
            resumeAt: playback.position.map { TimeInterval($0.positionMs) / 1000 },
            resumeSavedAt: playback.position.flatMap { GraphQLHelpers.parseISO8601($0.savedAt) }
        )
    }

    /// The content key for a key request. `offline` asks for one the iPhone
    /// may keep, for a title started with a download licence.
    static func contentKey(asin: String, request spc: Data, offline: Bool) async throws -> Data {
        let data = try await GraphQLHelpers.perform(
            GraphQLClient.shared.apollo,
            mutation: ShioriGraphQL.AudibleFairPlayKeyMutation(
                asin: asin,
                spc: spc.base64EncodedString(),
                offline: .some(offline)
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
