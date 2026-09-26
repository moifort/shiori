import SwiftUI

/// What a saga has for the reader, just under its introduction on the saga
/// screen: each volume out they do not hold, with the store it is found in and,
/// for a printed saga, the button that adds it to the library; then the next
/// one announced and its day. Drawn by the Découvrir domain, which looks the
/// saga up on the web every week.
struct SagaReleasesSection: View {
    let releases: SagaReleases
    let author: String
    /// The volume numbers the reader holds: a volume just added from here
    /// leaves the section at once rather than on the next look.
    let held: Set<Int>
    /// The add button of the saga screen for a volume, when it can be added —
    /// nil for a saga heard, bought on Audible rather than added by hand.
    let addButton: (DiscoveredVolume) -> AnyView?

    var body: some View {
        let available = releases.available.filter { !held.contains($0.number) }
        let next = releases.next.flatMap { held.contains($0.number) ? nil : $0 }
        if !available.isEmpty || next != nil {
            Section {
                ForEach(available) { volume in
                    row(volume, forthcoming: false)
                }
                if let next {
                    row(next, forthcoming: true)
                }
            } header: {
                Text("Prochaines sorties")
            } footer: {
                if next != nil {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Image(systemName: "bell")
                        Text("Vous recevrez une notification le jour de la sortie.")
                    }
                }
            }
            .accessibilityIdentifier("series-releases")
        }
    }

    private func row(_ volume: DiscoveredVolume, forthcoming: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            BookCover(book: Book(
                id: "release-\(volume.number)",
                title: volume.title,
                authors: [author],
                coverURL: volume.coverURL,
                status: .toRead
            ))
            .opacity(forthcoming ? 0.45 : 1)
            VStack(alignment: .leading, spacing: 3) {
                Text("Tome \(volume.number)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(volume.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                Group {
                    if forthcoming, let date = volume.date {
                        Text(ReleaseDateText.coming(date)).foregroundStyle(.orange)
                    } else if forthcoming {
                        Text("Annoncé").foregroundStyle(.orange)
                    } else {
                        Text("Disponible").foregroundStyle(Color.accentColor)
                    }
                }
                .font(.subheadline.weight(.medium))
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            if forthcoming {
                if let date = volume.date { ReleaseDateBadge(date: date) }
            } else {
                HStack(spacing: 10) {
                    StoreLink(volume: volume)
                    addButton(volume)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
