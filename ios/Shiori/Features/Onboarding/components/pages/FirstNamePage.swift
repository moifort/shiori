import SwiftUI

struct FirstNamePage: View {
    @Binding var firstName: String
    @Binding var avatar: AccountAvatar
    var onNext: () -> Void
    var onBack: () -> Void

    @FocusState private var focused: Bool
    @State private var pickingAvatar = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var trimmed: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            avatarButton
                .frame(maxWidth: .infinity)
                .entrance(appeared, delay: 0, sliding: !reduceMotion)

            VStack(alignment: .leading, spacing: 8) {
                Text("Comment vous appelez-vous ?")
                    .font(.title.bold())
                    // Never cut short when the keyboard leaves little room
                    // under the avatar: the field and the button give way.
                    .fixedSize(horizontal: false, vertical: true)
                Text("Votre prénom et votre avatar personnalisent l'application.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .entrance(appeared, delay: 0.04, sliding: !reduceMotion)

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
        .sheet(isPresented: $pickingAvatar) {
            AvatarPickerSheet(current: avatar, firstName: trimmed) { avatar = $0 }
        }
        .onAppear {
            appeared = true
            focused = true
        }
    }

    /// The avatar, large, with a pencil badge saying it can be changed.
    private var avatarButton: some View {
        Button { pickingAvatar = true } label: {
            AccountAvatarView(avatar: avatar, firstName: trimmed, size: 112)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "pencil")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .animation(.snappy, value: trimmed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Modifier l'avatar")
        .accessibilityIdentifier("onboarding-avatar")
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
        FirstNamePage(firstName: .constant("Thibaut"), avatar: .constant(.initials), onNext: {}, onBack: {})
    }
}
