import SwiftUI

/// Under a shown book's facts: a row while its description is being written,
/// then its summary.
struct ReleaseDescriptionSections: View {
    let isDescribing: Bool
    let synopsis: String?

    var body: some View {
        if isDescribing {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    ProgressView()
                    Text("Préparation de la fiche…")
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("release-describing")
            }
        } else if let synopsis, !synopsis.isEmpty {
            BookSynopsisSection(synopsis: synopsis)
        }
    }
}

#Preview("Release description") {
    List {
        ReleaseDescriptionSections(isDescribing: true, synopsis: nil)
        ReleaseDescriptionSections(isDescribing: false, synopsis: ReleaseDescription.preview.book.synopsis)
    }
}
