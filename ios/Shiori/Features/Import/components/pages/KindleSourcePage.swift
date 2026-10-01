import SwiftUI

/// What a reader sees of their Kindle connection: where it points, whether it
/// follows them, what the last pass brought back, and how much of the library
/// is already on the shelf.
///
/// Pure and previewable: it takes what to draw and what to call, and knows
/// nothing about the network.
struct KindleSourcePage: View {
    let account: KindleAccount
    /// How many books the Kindle library holds, and how many are catalogued.
    /// Both nil until the library has been read.
    let totalCount: Int?
    let catalogedCount: Int?
    let isLoading: Bool
    let isSyncing: Bool
    let lastSyncOutcome: SyncOutcome?
    let onAutoSyncChange: (Bool) -> Void
    let onSyncNow: () -> Void
    let onPickBooks: () -> Void
    let onReconnect: () -> Void
    let onDisconnect: () async -> Void

    var body: some View {
        List {
            if account.lastSyncFailedAt != nil { reconnectSection }
            connectionSection
            syncSection
            librarySection
            disconnectSection
        }
        .navigationTitle("Kindle")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Said first, and in so many words: a library gone quiet would otherwise
    /// read as nothing new to report.
    private var reconnectSection: some View {
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amazon a refusé la dernière synchronisation")
                        .font(.subheadline.weight(.semibold))
                    Text("Reconnectez votre compte pour que votre bibliothèque Kindle continue de vous suivre.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Button("Reconnecter mon compte Amazon", action: onReconnect)
                .accessibilityIdentifier("kindle-reconnect")
        }
    }

    private var connectionSection: some View {
        Section {
            LabeledContent("Boutique", value: account.marketplace.amazonLabel)
            if let connectedAt = account.connectedAt {
                LabeledContent("Connecté le", value: connectedAt.formatted(date: .abbreviated, time: .omitted))
            }
        } header: {
            Text("Compte")
        }
    }

    private var syncSection: some View {
        Section {
            Toggle(
                "Synchroniser chaque nuit",
                isOn: Binding(get: { account.autoSync }, set: onAutoSyncChange)
            )
            .accessibilityIdentifier("kindle-auto-sync")

            LabeledContent("Dernière synchronisation", value: lastSyncLabel)

            Button(action: onSyncNow) {
                HStack {
                    Text("Synchroniser maintenant")
                    Spacer()
                    if isSyncing { ProgressView() }
                }
            }
            .disabled(isSyncing)
            .accessibilityIdentifier("kindle-sync-now")

            if let lastSyncOutcome {
                Text(lastSyncOutcome.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Synchronisation")
        }
    }

    private var librarySection: some View {
        Section {
            if let totalCount, let catalogedCount {
                LabeledContent("Livres sur Kindle", value: "\(totalCount)")
                LabeledContent("Déjà dans votre bibliothèque", value: "\(catalogedCount)")
            } else {
                HStack {
                    Text("Lecture de votre bibliothèque Kindle...")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isLoading { ProgressView() }
                }
            }

            Button(action: onPickBooks) {
                Label("Choisir des livres à importer", systemImage: "checklist")
            }
            .disabled((totalCount ?? 0) == 0)
            .accessibilityIdentifier("kindle-pick-books")

            // The one mistake that fails silently: a library opened on the wrong
            // store reads as empty. Said only then.
            if totalCount == 0 {
                Text("Aucun livre Kindle sur ce compte. Vérifiez la boutique : une bibliothèque française ne s'ouvre pas depuis amazon.com.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Bibliothèque")
        }
    }

    private var disconnectSection: some View {
        Section {
            AsyncButton("Déconnecter Kindle", role: .destructive) { await onDisconnect() }
                .accessibilityIdentifier("kindle-disconnect")
        }
    }

    private var lastSyncLabel: String {
        guard let lastImportedAt = account.lastImportedAt else {
            return String(localized: "jamais")
        }
        let days = lastImportedAt.daysAgo()
        if days == 0 { return String(localized: "aujourd'hui") }
        if days == 1 { return String(localized: "hier") }
        return String(localized: "il y a \(days) j")
    }

}

#Preview("Connecté") {
    NavigationStack {
        KindleSourcePage(
            account: .preview,
            totalCount: 76,
            catalogedCount: 71,
            isLoading: false,
            isSyncing: false,
            lastSyncOutcome: SyncOutcome(imported: 1, updated: 2),
            onAutoSyncChange: { _ in },
            onSyncNow: {},
            onPickBooks: {},
            onReconnect: {},
            onDisconnect: {}
        )
    }
}

#Preview("Synchronisation refusée") {
    NavigationStack {
        KindleSourcePage(
            account: .refusedPreview,
            totalCount: nil,
            catalogedCount: nil,
            isLoading: false,
            isSyncing: false,
            lastSyncOutcome: nil,
            onAutoSyncChange: { _ in },
            onSyncNow: {},
            onPickBooks: {},
            onReconnect: {},
            onDisconnect: {}
        )
    }
}
