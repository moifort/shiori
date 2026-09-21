import SwiftUI

/// An invitation the reader arrived on by tapping a link, waiting to be taken up.
struct InvitationRequest: Identifiable, Equatable {
    let code: String
    var id: String { code }
}

/// What a tapped invitation link opens on.
///
/// It asks before it accepts. The link came from somewhere the reader does not
/// control — a message, a forwarded mail, a page — and accepting opens their
/// library to whoever sent it. One tap to arrive here is right; one tap to share
/// a library is not.
struct InvitationAcceptSheet: View {
    let request: InvitationRequest
    let onAccepted: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var accepted: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                Image(systemName: accepted == nil ? "person.2.badge.key" : "checkmark.seal.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                if let accepted {
                    Text("Vous partagez vos bibliothèques")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("\(accepted) voit votre bibliothèque, et vous voyez la sienne.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                    Button("Parfait") { dismiss() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Une bibliothèque vous est ouverte")
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text(request.code)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .kerning(5)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("invitation-accept-code")
                    Text("En acceptant, vous verrez ses lectures et il verra les vôtres. Vos notes de lecture et les livres marqués « ne pas partager » restent à vous.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer(minLength: 0)
                    AsyncButton("Accepter") { await accept() }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("invitation-accept")
                    Button("Pas maintenant") { dismiss() }
                        .font(.subheadline)
                }
            }
            .padding(28)
            .navigationTitle("Invitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarIconButton(title: "Fermer", systemImage: "xmark", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .alert(
                "Invitation refusée",
                isPresented: .init(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium])
    }

    private func accept() async {
        do {
            let friend = try await FriendsAPI.accept(code: request.code)
            accepted = friend.displayName
            onAccepted()
        } catch {
            errorMessage = reportError(error)
        }
    }
}
