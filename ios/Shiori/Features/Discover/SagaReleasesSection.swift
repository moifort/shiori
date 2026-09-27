import SwiftUI

/// The next volume of a saga announced, just under its introduction on the saga
/// screen, and the day it comes out. The volumes already out are not repeated
/// here: they are listed under "Tomes", with the button that adds them. Drawn
/// by the Découvrir domain, which looks the saga up on the web every week.
struct SagaReleasesSection: View {
    let releases: SagaReleases
    let author: String
    /// The volume numbers the reader holds: a volume added ahead of its day
    /// leaves the section at once rather than on the next look.
    let held: Set<Int>

    var body: some View {
        if let next = releases.next, !held.contains(next.number) {
            Section {
                row(next)
            } header: {
                Text("Prochaines sorties")
            } footer: {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Image(systemName: "bell")
                    Text("Vous recevrez une notification le jour de la sortie.")
                }
            }
            .accessibilityIdentifier("series-releases")
        }
    }

    private func row(_ volume: DiscoveredVolume) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BookCover(book: Book(
                id: "release-\(volume.number)",
                title: volume.title,
                authors: [author],
                coverURL: volume.coverURL,
                status: .toRead
            ))
            .opacity(0.45)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tome \(volume.number)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(volume.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Group {
                    if let date = volume.date {
                        Text(ReleaseDateText.coming(date))
                    } else {
                        Text("Annoncé")
                    }
                }
                .foregroundStyle(.orange)
                .font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if let date = volume.date { ReleaseDateBadge(date: date) }
        }
        .padding(.vertical, 4)
    }
}
