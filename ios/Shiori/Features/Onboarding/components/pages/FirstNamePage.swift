import SwiftUI

struct FirstNamePage: View {
    @Binding var firstName: String
    var onNext: () -> Void
    var onBack: () -> Void

    @FocusState private var focused: Bool
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
            .entrance(appeared, delay: 0, sliding: !reduceMotion)

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
                .entrance(appeared, delay: 0.08, sliding: !reduceMotion)

            Spacer()

            Button(action: onNext) {
                Text("Continuer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmed.isEmpty)
            .accessibilityIdentifier("onboarding-firstname-next")
            .entrance(appeared, delay: 0.16, sliding: !reduceMotion)
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
    /// One-shot staggered entrance: fade in while sliding up a few points, or
    /// only fade with Reduce Motion on.
    func entrance(_ appeared: Bool, delay: Double, sliding: Bool) -> some View {
        opacity(appeared ? 1 : 0)
            .offset(y: appeared || !sliding ? 0 : 14)
            .animation(.spring(duration: 0.45, bounce: 0.2).delay(delay), value: appeared)
    }
}

#Preview {
    NavigationStack {
        FirstNamePage(firstName: .constant("Thibaut"), onNext: {}, onBack: {})
    }
}
