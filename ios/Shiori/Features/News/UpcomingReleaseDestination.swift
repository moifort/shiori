import Foundation

/// What a release of "À venir" opens, as the home page, the saga screen and the
/// wishlist open their own: a saga's next volume on its announced page, an
/// edition awaited on its page, an author's work on the author, a narrator's
/// recording on the narrator. Never the full list, which only the section's
/// title opens.
///
/// Never awaited before a push: a tap pushes `UpcomingReleaseScreen`, which
/// looks the release up behind its loader.
enum UpcomingReleaseDestination {
    case announced(DiscoveryVolume)
    case awaited(AwaitedEdition)
    case author(AuthorDestination)
    case narrator(NarratorDestination)

    /// What the release itself names, with nothing to fetch: an author's
    /// page, a narrator's. Nil for a volume or an edition, which the release
    /// watches hold.
    static func immediate(_ release: UpcomingRelease) -> Self? {
        switch release.source {
        case .saga, .awaited:
            return nil
        case .author:
            return release.author.map { .author(AuthorDestination(key: $0.key, name: $0.name)) }
        case .narrator:
            // "narrator~<narrator key>~<title>".
            let parts = release.id.split(separator: "~", omittingEmptySubsequences: false)
            guard parts.count >= 2, let name = release.narrator else { return nil }
            return .narrator(NarratorDestination(key: String(parts[1]), name: name))
        }
    }

    /// Looks the release up among what the release watches already hold — no
    /// web lookup. Nil when the watch no longer lists it; throws when the
    /// watch could not be read.
    static func of(_ release: UpcomingRelease, client: DiscoverClient = .live) async throws -> Self? {
        let format: ReleaseFormat = release.format == .audiobook ? .audiobook : .book
        switch release.source {
        case .saga:
            let page = try await client.discovery(format)
            let row = page.rows.first { row in
                row.series.name == release.seriesName
                    && row.releases.next?.number == release.volume
                    && (release.language == nil || row.series.language == release.language)
            }
            guard let row, let next = row.releases.next else { return nil }
            return .announced(DiscoveryVolume(saga: row, volume: next))
        case .awaited:
            // "awaited~<edition id>", the server's id for a wait.
            let editionId = String(release.id.dropFirst("awaited~".count))
            let editions = try await client.awaited(format)
            return editions.first { $0.id == editionId }.map { .awaited($0) }
        case .author, .narrator:
            return immediate(release)
        }
    }
}
