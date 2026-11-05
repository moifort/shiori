import Foundation

/// What a release of "À venir" opens, as the home page, the saga screen and the
/// wishlist open their own: a saga's next volume on its announced page, an
/// edition awaited on its page, an author's work on the author, a narrator's
/// recording on the narrator. Never the full list, which only the section's
/// title opens.
enum UpcomingReleaseDestination {
    case announced(DiscoveryVolume)
    case awaited(AwaitedEdition)
    case author(AuthorDestination)
    case narrator(NarratorDestination)

    /// Looks the release up among what the release watches already hold — no
    /// web lookup. Nil when the watch no longer lists it.
    static func of(_ release: UpcomingRelease, client: DiscoverClient = .live) async -> Self? {
        let format: ReleaseFormat = release.format == .audiobook ? .audiobook : .book
        switch release.source {
        case .saga:
            guard let page = try? await client.discovery(format) else { return nil }
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
            guard let editions = try? await client.awaited(format),
                  let edition = editions.first(where: { $0.id == editionId })
            else { return nil }
            return .awaited(edition)
        case .author:
            return release.author.map { .author(AuthorDestination(key: $0.key, name: $0.name)) }
        case .narrator:
            // "narrator~<narrator key>~<title>".
            let parts = release.id.split(separator: "~", omittingEmptySubsequences: false)
            guard parts.count >= 2, let name = release.narrator else { return nil }
            return .narrator(NarratorDestination(key: String(parts[1]), name: name))
        }
    }
}
