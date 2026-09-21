import SwiftUI

/// Lets the reader write to us: a problem to report, or an idea for the app.
/// The message goes straight to Sentry, where the errors already land.
///
/// The send is fire-and-forget: the SDK queues the message and retries on its
/// own, so there is nothing to await and the confirmation below is optimistic.
struct FeedbackSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var kind: FeedbackKind = .bug
    @State private var message = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ZStack {
                if sent {
                    confirmation
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                } else {
                    composer
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.3), value: sent)
            .sensoryFeedback(.success, trigger: sent)
            .navigationTitle("Nous écrire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(
                        title: sent ? "Terminé" : "Annuler",
                        systemImage: "xmark",
                        role: .cancel
                    ) { dismiss() }
                }
            }
            .task(id: sent) {
                guard sent else { return }
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled else { return }
                dismiss()
            }
        }
    }

    private var composer: some View {
        Form {
            Section {
                Picker("Sujet", selection: $kind) {
                    Text("Problème").tag(FeedbackKind.bug)
                    Text("Suggestion").tag(FeedbackKind.idea)
                }
                .pickerStyle(.segmented)
            } footer: {
                Text(kindHint)
            }

            Section {
                TextField("Votre message", text: $message, axis: .vertical)
                    .lineLimit(5...)
                    .accessibilityIdentifier("feedback-message")
            }

            Section {
                Button("Envoyer") { send() }
                    .disabled(trimmedMessage.isEmpty)
                    .accessibilityIdentifier("feedback-send")
            } footer: {
                Text("La version de l'application et le modèle d'appareil accompagnent le message. Ni votre nom ni votre adresse e-mail ne sont transmis.")
            }
        }
    }

    /// Centred confirmation that replaces the form once the message is queued,
    /// then steps aside on its own after a couple of seconds.
    private var confirmation: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, options: .nonRepeating, value: sent)

            Text("Message envoyé")
                .font(.title3.weight(.semibold))

            Text("Merci, votre message nous aide à améliorer l'application.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var kindHint: LocalizedStringKey {
        switch kind {
        case .bug: "Décrivez ce que vous faisiez et ce qui s'est passé."
        case .idea: "Dites-nous ce qui manque ou ce qui gagnerait à changer."
        }
    }

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func send() {
        sendFeedback(kind: kind, message: trimmedMessage)
        sent = true
    }
}

#Preview {
    FeedbackSheet()
}
