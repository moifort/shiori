import SwiftUI

/// One work in detail: what the reader read, then every edition in their
/// language, one card per format, each out or dated.
struct TranslationView: View {
    let translation: Translation
    let onDismiss: () -> Void
    @Environment(\.dismiss) private var close
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        BookCover(book: translation.book, width: 64, showsFormatBadge: false)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(translation.title).font(.headline)
                            if let author = translation.author {
                                Text(author).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("En \(translation.originalLanguage.label.lowercased()) — vous avez lu") {
                    LabeledContent(translation.originalTitle, value: readLine)
                }

                ForEach(translation.formats, id: \.self) { format in
                    Section {
                        ForEach(translation.editions.filter { $0.format == format }) { edition in
                            editionRow(edition)
                        }
                    } header: {
                        Label("En français — \(format.label.lowercased())", systemImage: format.symbol)
                    }
                }

                Section {
                    Button("Pas intéressé", role: .destructive) {
                        onDismiss()
                        close()
                    }
                    .accessibilityIdentifier("translation-dismiss")
                } footer: {
                    Text("Ce livre ne vous sera plus proposé, et vous ne serez pas prévenu de ses sorties.")
                }
            }
            .navigationTitle(translation.isSeries ? translation.title : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") { close() }
                }
            }
        }
    }

    private var readLine: String {
        guard translation.isSeries, !translation.volumesRead.isEmpty else { return String(localized: "Lu") }
        return Self.volumeRange(translation.volumesRead)
    }

    @ViewBuilder
    private func editionRow(_ edition: TranslatedEdition) -> some View {
        let label = edition.volume.map { String(localized: "Tome \($0)") } ?? edition.title
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                if edition.volume != nil, edition.title != label {
                    Text(edition.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            Spacer()
            if edition.isUpcoming, let date = edition.date {
                Text(ReleaseDateText.phrase(date)).font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
            } else {
                Text("Disponible").font(.subheadline.weight(.semibold)).foregroundStyle(.green)
            }
            if let url = edition.audibleURL {
                Button {
                    openURL(url)
                } label: {
                    Image(systemName: "arrow.up.forward.square")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Ouvrir dans Audible"))
            }
        }
    }

    /// "Tome 3", "Tomes 1 à 3", or "Tomes 1, 3, 4" — as few words as the
    /// numbers allow.
    static func volumeRange(_ volumes: [Int]) -> String {
        let sorted = volumes.sorted()
        guard let first = sorted.first, let last = sorted.last else { return "" }
        if sorted.count == 1 { return String(localized: "Tome \(first)") }
        if last - first + 1 == sorted.count { return String(localized: "Tomes \(first) à \(last)") }
        return String(localized: "Tomes \(sorted.map(String.init).joined(separator: ", "))")
    }

    /// What of a saga is out already, for a row with nothing still to come.
    static func availableVolumes(_ editions: [TranslatedEdition]) -> String {
        let volumes = Array(Set(editions.filter { !$0.isUpcoming }.compactMap(\.volume)))
        guard !volumes.isEmpty else { return String(localized: "Disponible") }
        return volumes.count == 1
            ? String(localized: "\(volumeRange(volumes)) disponible")
            : String(localized: "\(volumeRange(volumes)) disponibles")
    }
}
