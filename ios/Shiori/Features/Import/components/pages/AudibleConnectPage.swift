import SwiftUI

/// What a reader sees before their Amazon account is linked: what the import
/// does, which store to sign in on, and one button.
///
/// The store comes first because getting it wrong is the one mistake that fails
/// silently — a French account signed in on audible.com finds an empty library
/// and reads as "the import is broken".
struct AudibleConnectPage: View {
    @Binding var marketplace: AudibleMarketplace
    let isWorking: Bool
    let onConnect: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "headphones")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Importez votre bibliothèque Audible")
                        .font(.title3.bold())
                    Text(
                        "Connectez votre compte Amazon une fois, puis choisissez les livres "
                            + "audio à ajouter. Ils rejoignent votre bibliothèque avec leur "
                            + "couverture, leur série et votre avancement d'écoute."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                Picker("Boutique Audible", selection: $marketplace) {
                    ForEach(AudibleMarketplace.allCases) { store in
                        Text(store.label).tag(store)
                    }
                }
                .accessibilityIdentifier("audible-marketplace")
            } header: {
                Text("Boutique")
            } footer: {
                Text("Celle sur laquelle vous achetez vos livres audio.")
            }

            Section {
                Button(action: onConnect) {
                    HStack {
                        Text("Connecter mon compte Amazon")
                        Spacer()
                        if isWorking { ProgressView() }
                    }
                }
                .disabled(isWorking)
                .accessibilityIdentifier("audible-connect")
            } footer: {
                Text(
                    "La page de connexion est celle d'Amazon : votre mot de passe ne passe "
                        + "jamais par Shiori. L'import ne consomme aucun scan."
                )
            }
        }
        .navigationTitle("Audible")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @Previewable @State var marketplace: AudibleMarketplace = .fr
    NavigationStack {
        AudibleConnectPage(marketplace: $marketplace, isWorking: false, onConnect: {})
    }
}
