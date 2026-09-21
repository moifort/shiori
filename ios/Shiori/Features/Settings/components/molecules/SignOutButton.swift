import SwiftUI

struct SignOutButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            HStack {
                Spacer()
                Label {
                    Text("Se déconnecter")
                } icon: {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }
                Spacer()
            }
        }
        .accessibilityIdentifier("sign-out")
    }
}
