import SwiftUI

/// The last onboarding step: an offer, never a requirement. A reader who
/// listens on Audible already has a library waiting, and bringing it in now
/// spares them a first visit to an empty shelf. Everyone else skips it in one
/// tap and lands in the app as before.
struct AudibleOfferPage: View {
    /// Amazon's page is being prepared, or the account linked.
    var isWorking: Bool = false
    var onConnect: () -> Void
    var onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Image(systemName: "headphones")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.orange, in: .rect(cornerRadius: 22))
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.8)
                .animation(.spring(duration: 0.45, bounce: 0.3), value: appeared)

            VStack(alignment: .leading, spacing: 8) {
                Text("Vous écoutez sur Audible ?")
                    .font(.title.bold())
                Text("Connectez votre compte Amazon : toute votre bibliothèque Audible est importée pendant que vous découvrez l'application, avec le genre, la série et ce que vous avez déjà écouté. Vous pourrez aussi le faire plus tard depuis les réglages.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.08), value: appeared)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onConnect) {
                    ZStack {
                        Label("Importer depuis Audible", systemImage: "arrow.down.circle")
                            .opacity(isWorking ? 0 : 1)
                        if isWorking { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding-audible-connect")

                Button(action: onSkip) {
                    Text("Plus tard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("onboarding-audible-skip")
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.16), value: appeared)
        }
        .padding()
        .onAppear { appeared = true }
    }
}

#Preview {
    AudibleOfferPage(onConnect: {}, onSkip: {})
}
