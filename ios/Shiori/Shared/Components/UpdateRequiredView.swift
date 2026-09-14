import SwiftUI

/// Blocking screen shown when the running build is below the backend's minimum
/// supported build. No dismissal: the only way forward is the App Store update.
struct UpdateRequiredView: View {
    let appStoreURL: URL

    var body: some View {
        ContentUnavailableView {
            Label("Mise à jour requise", systemImage: "arrow.down.app")
        } description: {
            Text("Cette version de Shiori n'est plus compatible avec le serveur. La dernière version est disponible sur l'App Store.")
        } actions: {
            Link("Mettre à jour", destination: appStoreURL)
                .font(.headline)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }
}

#Preview {
    UpdateRequiredView(appStoreURL: URL(string: "https://apps.apple.com/app/id6789688303")!)
}
