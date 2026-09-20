import SwiftUI

struct WelcomePage: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            RibbonMark(motion: .once)
            VStack(spacing: 12) {
                Text("Bienvenue dans Shiori")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                Text("Photographiez la couverture d'un livre, et il rejoint votre bibliothèque avec son résumé, sa série et tout le reste.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
            Spacer()
            Button(action: onNext) {
                Text("Commencer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("onboarding-start")
        }
        .padding()
    }
}

#Preview {
    WelcomePage(onNext: {})
}
