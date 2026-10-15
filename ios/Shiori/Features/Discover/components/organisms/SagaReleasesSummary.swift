import SwiftUI

/// What a saga has for the reader, in a line under its covers, as the section
/// it is in says: among the new releases, the volumes out they have not added
/// yet; among the announcements, the next volume — its date already hangs
/// under its cover.
struct SagaReleasesSummary: View {
    enum Section { case recent, upcoming }

    let releases: SagaReleases
    let missing: [Int]
    let section: Section

    var body: some View {
        if let line = section == .recent ? availablePart : comingPart {
            Text(verbatim: line)
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(2)
        }
    }

    private var comingPart: String? {
        releases.next.map { String(localized: "À venir : Tome \($0.number)") }
    }

    private var availablePart: String? {
        guard !missing.isEmpty else { return nil }
        let numbers = missing.map(String.init).joined(separator: ", ")
        return String(localized: "Disponible : Tome \(numbers)")
    }
}

#Preview("Saga releases summary") {
    List {
        SagaReleasesSummary(releases: SagaDiscovery.preview.releases, missing: [], section: .upcoming)
        SagaReleasesSummary(
            releases: SagaDiscovery.previewRead.releases,
            missing: SagaDiscovery.previewRead.missing,
            section: .recent
        )
    }
}
