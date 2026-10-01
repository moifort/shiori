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
            Label {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amazon a refusé la dernière synchronisation")
                        .font(.subheadline.weight(.semibold))
                    Text("Reconnectez votre compte pour que votre bibliothèque Kindle continue de vous suivre.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
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
        } footer: {
            Text(
                "Votre mot de passe n'est jamais passé par Shiori, et vos identifiants "
                    + "Amazon ne quittent pas le serveur."
            )
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
        } footer: {
            // It writes into the library without asking again, so it says what
            // it does — and what it never does — where the reader can read it.
            Text(
                "Les livres Kindle achetés ou empruntés depuis la dernière fois rejoignent "
                    + "votre bibliothèque, et ceux que Kindle marque comme lus le deviennent "
                    + "ici. Rien n'est jamais remis à lire, et vos notes ne sont jamais modifiées."
            )
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
        } header: {
            Text("Bibliothèque")
        } footer: {
            Text(remainingLabel)
        }
    }

    private var disconnectSection: some View {
        Section {
            AsyncButton("Déconnecter Kindle", role: .destructive) { await onDisconnect() }
                .accessibilityIdentifier("kindle-disconnect")
        } footer: {
            Text(
                "Shiori oublie ses identifiants ; les livres déjà importés restent dans "
                    + "votre bibliothèque. L'appareil « Kindle for iPhone » reste enregistré "
                    + "chez Amazon jusqu'à ce que vous l'y retiriez."
            )
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

    private var remainingLabel: String {
        guard let totalCount, let catalogedCount else {
            return String(localized: "L'import ne consomme aucun scan.")
        }
        if totalCount == 0 {
            return String(localized: "Aucun livre Kindle sur ce compte. Vérifiez la boutique : une bibliothèque française ne s'ouvre pas depuis amazon.com.")
        }
        let remaining = max(0, totalCount - catalogedCount)
        return remaining == 0
            ? String(localized: "Toute votre bibliothèque Kindle est cataloguée.")
            : String(localized: "\(remaining) titre(s) pas encore catalogué(s). L'import ne consomme aucun scan.")
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
