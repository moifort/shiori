import SwiftUI

struct FirstNamePage: View {
    @Binding var firstName: String
    var onNext: () -> Void
    var onBack: () -> Void

    @FocusState private var focused: Bool
    @State private var appeared = false

    private var trimmed: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Comment vous appelez-vous ?")
                    .font(.title.bold())
                Text("Votre prénom sert à personnaliser l'application.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .entrance(appeared, delay: 0)

            TextField("Prénom", text: $firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .focused($focused)
                .onSubmit { if !trimmed.isEmpty { onNext() } }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("onboarding-firstname-field")
                .entrance(appeared, delay: 0.08)

            Spacer()

            Button(action: onNext) {
                Text("Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmed.isEmpty)
            .accessibilityIdentifier("onboarding-firstname-next")
            .entrance(appeared, delay: 0.16)
        }
        .padding()
        .navigationTitle("Prénom")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ToolbarIconButton(title: "Retour", systemImage: "chevron.left", action: onBack)
            }
        }
        .onAppear {
            appeared = true
            focused = true
        }
    }
}

private extension View {
    /// One-shot staggered entrance: fade in while sliding up a few points.
    func entrance(_ appeared: Bool, delay: Double) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 14)
            .animation(.spring(duration: 0.45, bounce: 0.2).delay(delay), value: appeared)
    }
}

#Preview {
    NavigationStack {
        FirstNamePage(firstName: .constant("Thibaut"), onNext: {}, onBack: {})
    }
}
