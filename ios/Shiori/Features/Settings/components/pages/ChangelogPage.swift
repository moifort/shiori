import SwiftUI

/// What each version changed, the newest version first, and a pending
/// section on top when one is being written.
struct ChangelogPage: View {
    let entries: [ChangelogEntry]
    let isLoading: Bool
    let errorMessage: String?
    let onRefresh: () async -> Void

    var body: some View {
        Group {
            if isLoading && entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, entries.isEmpty {
                EmptyState.failure("Notes de version indisponibles", message: errorMessage) {
                    await onRefresh()
                }
            } else {
                List(entries) { entry in
                    Section {
                        ForEach(Array(entry.notes.enumerated()), id: \.offset) { _, note in
                            Label {
                                Text(note)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 5))
                                    .foregroundStyle(.secondary)
                            }
                            .labelStyle(.caption)
                            .font(.callout)
                        }
                    } header: {
                        HStack {
                            Text(entry.version)
                            Spacer()
                            if let date = entry.date {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                            } else {
                                Text("À venir")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await onRefresh() }
            }
        }
        .navigationTitle("Nouveautés")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ChangelogPage(entries: ChangelogEntry.previews, isLoading: false, errorMessage: nil) {}
    }
}
