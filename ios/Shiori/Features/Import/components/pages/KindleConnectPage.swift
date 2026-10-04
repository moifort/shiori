import SwiftUI

/// What a reader sees before their Kindle library is linked: what the
/// connection does, which store to sign in on, and one button.
///
/// The store comes first because getting it wrong fails silently — a French
/// library signed in on amazon.com reads as empty.
struct KindleConnectPage: View {
    @Binding var marketplace: AmazonMarketplace
    let isWorking: Bool
    let onConnect: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "book.closed")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text("Importez votre bibliothèque Kindle")
                        .font(.title3.bold())
                    Text(
                        "Connectez votre compte Amazon une fois, puis choisissez les livres à ajouter. Ils rejoignent votre bibliothèque avec leur couverture et leur série, et ceux que vous avez finis sur Kindle sont marqués comme lus."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                MenuPicker(
                    "Boutique Amazon",
                    selection: $marketplace,
                    options: AmazonMarketplace.allCases,
                    label: { $0.amazonLabel }
                )
                .accessibilityIdentifier("kindle-marketplace")
            } header: {
                Text("Boutique")
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
                .accessibilityIdentifier("kindle-connect")
            }
        }
        .navigationTitle("Kindle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    @Previewable @State var marketplace: AmazonMarketplace = .fr
    NavigationStack {
        KindleConnectPage(marketplace: $marketplace, isWorking: false, onConnect: {})
    }
}
