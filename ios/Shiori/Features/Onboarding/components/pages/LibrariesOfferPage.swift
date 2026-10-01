import SwiftUI

/// The last onboarding step: an offer, never a requirement. A reader who
/// listens on Audible or reads on Kindle already has a library waiting, and
/// bringing it in now spares them a first visit to an empty shelf. Each source
/// is a connection of its own, so the reader switches on only what they use;
/// everyone else goes on in one tap.
struct LibrariesOfferPage: View {
    @Binding var connectsAudible: Bool
    @Binding var connectsKindle: Bool
    /// The store to sign in on, for both: guessed from the device region, shown
    /// so the reader can confirm it or change it.
    @Binding var marketplace: AmazonMarketplace
    /// Amazon's page is being prepared, or an account linked.
    var isWorking: Bool = false
    var onConnect: () -> Void
    var onSkip: () -> Void

    @State private var appeared = false

    private var hasChoice: Bool { connectsAudible || connectsKindle }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.orange, in: .rect(cornerRadius: 22))
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(.spring(duration: 0.45, bounce: 0.3), value: appeared)

            VStack(alignment: .leading, spacing: 8) {
                Text("Vos bibliothèques")
                    .font(.title.bold())
                Text("Connectez celles que vous utilisez : elles sont importées pendant que vous découvrez l'application, puis suivies chaque nuit. Vous pourrez aussi le faire plus tard depuis les réglages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.08), value: appeared)

            VStack(spacing: 0) {
                sourceToggle(
                    isOn: $connectsAudible,
                    symbol: "headphones",
                    title: "Audible",
                    detail: "Vos livres audio, avec ce que vous avez déjà écouté.",
                    identifier: "onboarding-connect-audible"
                )
                Divider().padding(.leading, 44)
                sourceToggle(
                    isOn: $connectsKindle,
                    symbol: "book.closed",
                    title: "Kindle",
                    detail: "Vos livres numériques, avec ceux que vous avez finis.",
                    identifier: "onboarding-connect-kindle"
                )
                Divider().padding(.leading, 44)
                // One store for both: a reader buys on one Amazon, almost always.
                MenuPicker(
                    selection: $marketplace,
                    options: AmazonMarketplace.allCases,
                    label: { $0.amazonLabel }
                ) {
                    Text("Boutique")
                }
                .padding(.vertical, 10)
                .accessibilityIdentifier("onboarding-marketplace")
            }
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
            .disabled(isWorking)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.12), value: appeared)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onConnect) {
                    ZStack {
                        Label("Connecter", systemImage: "arrow.down.circle")
                            .opacity(isWorking ? 0 : 1)
                        if isWorking { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isWorking || !hasChoice)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding-libraries-connect")

                Button(action: onSkip) {
                    Text("Plus tard")
                        .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding-libraries-skip")
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.16), value: appeared)
        }
        .padding()
        .onAppear { appeared = true }
    }

    private func sourceToggle(
        isOn: Binding<Bool>,
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        identifier: String
    ) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .accessibilityIdentifier(identifier)
    }
}

#Preview("Rien de coché") {
    @Previewable @State var audible = false
    @Previewable @State var kindle = false
    @Previewable @State var marketplace: AmazonMarketplace = .fr
    LibrariesOfferPage(
        connectsAudible: $audible,
        connectsKindle: $kindle,
        marketplace: $marketplace,
        onConnect: {},
        onSkip: {}
    )
}

#Preview("Les deux") {
    @Previewable @State var audible = true
    @Previewable @State var kindle = true
    @Previewable @State var marketplace: AmazonMarketplace = .fr
    LibrariesOfferPage(
        connectsAudible: $audible,
        connectsKindle: $kindle,
        marketplace: $marketplace,
        onConnect: {},
        onSkip: {}
    )
}
