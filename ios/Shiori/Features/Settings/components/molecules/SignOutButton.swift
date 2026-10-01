import SwiftUI

struct SignOutButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label {
                Text("Se déconnecter")
            } icon: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .foregroundStyle(.red)
            }
        }
        .accessibilityIdentifier("sign-out")
    }
}
