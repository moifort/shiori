import SwiftUI

/// What each version changed, served by the backend in the reader's language
/// from the changelog the release was cut from. The newest version first, and
/// a pending section on top when one is being written.
struct ChangelogListView: View {
    @State private var entries: [ChangelogEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if isLoading && entries.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, entries.isEmpty {
                EmptyStateView.failure("Notes de version indisponibles", message: errorMessage) {
                    await load()
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
                .refreshable { await load() }
            }
        }
        .navigationTitle("Nouveautés")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            entries = try await SettingsAPI.changelog()
        } catch {
            errorMessage = reportError(error)
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack { ChangelogListView() }
}
