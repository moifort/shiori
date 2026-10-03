import SwiftUI

/// The next volume of a saga announced, just under its introduction on the saga
/// screen, and the day it comes out. The volumes already out are not repeated
/// here: they are listed under "Tomes", with the button that adds them. Drawn
/// by the Découvrir domain, which looks the saga up on the web every two weeks. A
/// tap opens the volume's page, as on Découvrir.
struct SagaReleasesSection: View {
    let releases: SagaReleases
    let author: String
    /// The volume numbers the reader holds: a volume added ahead of its day
    /// leaves the section at once rather than on the next look.
    let held: Set<Int>
    /// A saga heard: the cover carries the headphones.
    let isAudio: Bool
    /// Opens the volume's page, as Découvrir opens it.
    let open: (DiscoveredVolume) -> Void

    var body: some View {
        if let next = releases.next, !held.contains(next.number) {
            Section {
                Button { open(next) } label: { row(next) }
                    .tint(.primary)
            } header: {
                Text("Prochaines sorties")
            }
            .accessibilityIdentifier("series-releases")
        }
    }

    private func row(_ volume: DiscoveredVolume) -> some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: Book(
                id: "release-\(volume.number)",
                title: volume.title,
                authors: [author],
                format: isAudio ? .audiobook : .book,
                coverURL: volume.coverURL,
                status: .toRead
            ))
            VStack(alignment: .leading, spacing: 3) {
                Text("Tome \(volume.number)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(volume.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                // The day is the calendar leaf's to say: the line only says
                // what the leaf cannot, a volume announced with no date.
                if volume.date == nil {
                    Text("Annoncé")
                        .foregroundStyle(.orange)
                        .font(.subheadline.weight(.medium))
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let date = volume.date { ReleaseDateBadge(date: date) }
        }
        .padding(.vertical, 4)
    }
}
