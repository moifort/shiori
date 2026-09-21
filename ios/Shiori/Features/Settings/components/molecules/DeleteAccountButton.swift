import SwiftUI

struct DeleteAccountButton: View {
    var isDeleting: Bool
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                Spacer()
                if isDeleting {
                    ProgressView()
                } else {
                    Label {
                        Text("Supprimer mon compte")
                    } icon: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red)
                    }
                }
                Spacer()
            }
        }
        .disabled(isDeleting)
        .accessibilityIdentifier("delete-account")
    }
}
