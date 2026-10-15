import SwiftUI

/// What an author has for the reader in the format on screen, just under the
/// heading of their page, drawn as a saga's "Prochaines sorties" are:
/// "Annoncés" — the next work the web found and the editions of theirs the
/// reader awaits that are announced, the soonest first — then "Nouveautés" —
/// the works out in the last three months and the editions awaited now out,
/// the newest first. Drawn by the Découvrir domain, which looks the author up
/// on the web every month. A recording Audible confirmed opens on Audible; an
/// edition awaited opens its own page, as Découvrir opens it.
struct AuthorReleasesSection: View {
    let releases: AuthorReleases
    let author: String
    /// The author heard: the covers carry the headphones.
    let isAudio: Bool
    let onOpenAwaited: (AwaitedEdition) -> Void
    let onStopAwaiting: (AwaitedEdition) -> Void

    @Environment(\.openURL) private var openURL

    /// A work the web found or an edition the reader awaits, in one list.
    private enum Entry: Identifiable {
        case work(DiscoveredWork)
        case awaited(AwaitedEdition)

        var id: String {
            switch self {
            case let .work(work): "work-\(work.id)"
            case let .awaited(edition): "awaited-\(edition.id)"
            }
        }

        var day: String? {
            switch self {
            case let .work(work): work.date.map(ReleaseDateText.lastDay)
            case let .awaited(edition): edition.date.map(ReleaseDateText.lastDay)
            }
        }
    }

    private var announced: [Entry] {
        let entries = (releases.next.map { [Entry.work($0)] } ?? [])
            + releases.awaited.filter { $0.state == .announced }.map(Entry.awaited)
        return entries.sorted { lhs, rhs in
            guard let left = lhs.day else { return false }
            guard let right = rhs.day else { return true }
            return left < right
        }
    }

    private var out: [Entry] {
        let entries = releases.recent.map(Entry.work)
            + releases.awaited.filter { $0.state == .available }.map(Entry.awaited)
        return entries.sorted { ($0.day ?? "") > ($1.day ?? "") }
    }

    var body: some View {
        if !announced.isEmpty {
            Section {
                ForEach(announced) { row($0, isOut: false) }
            } header: {
                Text("Annoncés")
            }
            .accessibilityIdentifier("author-releases-next")
        }
        if !out.isEmpty {
            Section {
                ForEach(out) { row($0, isOut: true) }
            } header: {
                Text("Nouveautés")
            }
            .accessibilityIdentifier("author-releases-recent")
        }
    }

    @ViewBuilder
    private func row(_ entry: Entry, isOut: Bool) -> some View {
        switch entry {
        case let .work(work):
            if let audibleURL = work.audibleURL {
                Button { openURL(audibleURL) } label: { WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut) }
                    .tint(.primary)
                    .edgeToEdgeSeparator()
            } else {
                WorkReleaseRow(work: work, author: author, isAudio: isAudio, isOut: isOut)
                    .edgeToEdgeSeparator()
            }
        case let .awaited(edition):
            Button { onOpenAwaited(edition) } label: { AwaitedEditionReleaseRow(edition: edition) }
                .tint(.primary)
                .contextMenu {
                    if let url = edition.storeURL {
                        Button(edition.format.storeName, systemImage: "arrow.up.right.square") {
                            openURL(url)
                        }
                    }
                    Button("Ne plus suivre", systemImage: "bell.slash", role: .destructive) {
                        onStopAwaiting(edition)
                    }
                }
                .edgeToEdgeSeparator()
                .accessibilityIdentifier("author-awaited")
        }
    }
}

#Preview {
    List {
        AuthorReleasesSection(
            releases: AuthorReleases(
                next: AuthorDiscovery.preview.next,
                recent: [DiscoveredWork(
                    title: "The Butcher's Masquerade",
                    date: "2026-09-02",
                    isbn13: nil,
                    coverURL: nil,
                    seriesName: "Dungeon Crawler Carl",
                    volume: 5
                )],
                awaited: [.preview]
            ),
            author: "Matt Dinniman",
            isAudio: true,
            onOpenAwaited: { _ in },
            onStopAwaiting: { _ in }
        )
    }
}
