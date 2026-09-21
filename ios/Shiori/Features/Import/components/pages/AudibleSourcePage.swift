import SwiftUI

/// What a reader sees of their Audible connection: where it points, whether it
/// follows them, what the last pass brought back, and how much of the library is
/// already on the shelf.
///
/// The screen the import now opens on. Picking titles is one tap further in,
/// because it is the rare act: a connected library keeps itself up to date, and
/// what a reader comes here to do is check on it.
///
/// Pure and previewable: it takes what to draw and what to call, and knows
/// nothing about the network.
struct AudibleSourcePage: View {
    let account: AudibleAccount
    /// How many titles the Audible library holds, and how many are catalogued.
    /// Both nil until the library has been read.
    let totalCount: Int?
    let catalogedCount: Int?
    let isLoading: Bool
    let isSyncing: Bool
    /// What the pass the reader just asked for changed. Nil until they ask.
    let lastSyncOutcome: AudibleSyncOutcome?
    let onAutoSyncChange: (Bool) -> Void
    let onSyncNow: () -> Void
    let onPickBooks: () -> Void
    let onDisconnect: () async -> Void

    var body: some View {
        List {
            connectionSection
            syncSection
            librarySection
            disconnectSection
        }
        .navigationTitle("Audible")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var connectionSection: some View {
        Section {
            LabeledContent("Boutique", value: account.marketplace.label)
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
            .accessibilityIdentifier("audible-auto-sync")

            LabeledContent("Dernière synchronisation", value: lastSyncLabel)

            Button(action: onSyncNow) {
                HStack {
                    Text("Synchroniser maintenant")
                    Spacer()
                    if isSyncing { ProgressView() }
                }
            }
            .disabled(isSyncing)
            .accessibilityIdentifier("audible-sync-now")

            if let lastSyncOutcome {
                Text(lastSyncOutcome.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Synchronisation")
        } footer: {
            // Stated here rather than buried in a menu: it writes books into the
            // library without asking again, so it says what it does where the
            // reader can read it.
            Text(
                "Les livres audio achetés depuis la dernière fois rejoignent votre "
                    + "bibliothèque, et ceux que vous avez terminés sur Audible sont marqués "
                    + "comme lus. Vos notes et vos commentaires ne sont jamais modifiés."
            )
        }
    }

    private var librarySection: some View {
        Section {
            if let totalCount, let catalogedCount {
                LabeledContent("Livres audio sur Audible", value: "\(totalCount)")
                LabeledContent("Déjà dans votre bibliothèque", value: "\(catalogedCount)")
            } else {
                HStack {
                    Text("Lecture de votre bibliothèque Audible...")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isLoading { ProgressView() }
                }
            }

            Button(action: onPickBooks) {
                Label("Choisir des livres à importer", systemImage: "checklist")
            }
            .disabled((totalCount ?? 0) == 0)
            .accessibilityIdentifier("audible-pick-books")
        } header: {
            Text("Bibliothèque")
        } footer: {
            Text(remainingLabel)
        }
    }

    private var disconnectSection: some View {
        Section {
            AsyncButton("Déconnecter Audible", role: .destructive) { await onDisconnect() }
                .accessibilityIdentifier("audible-disconnect")
        } footer: {
            Text(
                "Shiori oublie ses identifiants ; les livres déjà importés restent dans "
                    + "votre bibliothèque. L'appareil reste enregistré chez Amazon jusqu'à ce "
                    + "que vous l'y retiriez."
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
        // The one mistake that fails silently: a French account signed in on
        // audible.com finds nothing and reads as "the import is broken". Said here
        // because this is the screen that can change the store.
        if totalCount == 0 {
            return String(localized: "Aucun livre audio sur ce compte. Vérifiez la boutique : une bibliothèque française ne s'ouvre pas depuis audible.com.")
        }
        let remaining = max(0, totalCount - catalogedCount)
        return remaining == 0
            ? String(localized: "Toute votre bibliothèque Audible est cataloguée.")
            : String(localized: "\(remaining) titre(s) pas encore catalogué(s). L'import ne consomme aucun scan.")
    }
}

#Preview("Connecté") {
    NavigationStack {
        AudibleSourcePage(
            account: AudibleAccount(
                marketplace: .fr,
                connectedAt: Date().addingTimeInterval(-86400 * 40),
                lastImportedAt: Date().addingTimeInterval(-86400 * 2),
                autoSync: true
            ),
            totalCount: 128,
            catalogedCount: 124,
            isLoading: false,
            isSyncing: false,
            lastSyncOutcome: AudibleSyncOutcome(imported: 2, updated: 1),
            onAutoSyncChange: { _ in },
            onSyncNow: {},
            onPickBooks: {},
            onDisconnect: {}
        )
    }
}

#Preview("Jamais synchronisé") {
    NavigationStack {
        AudibleSourcePage(
            account: AudibleAccount(
                marketplace: .com,
                connectedAt: Date(),
                lastImportedAt: nil,
                autoSync: false
            ),
            totalCount: nil,
            catalogedCount: nil,
            isLoading: true,
            isSyncing: false,
            lastSyncOutcome: nil,
            onAutoSyncChange: { _ in },
            onSyncNow: {},
            onPickBooks: {},
            onDisconnect: {}
        )
    }
}
