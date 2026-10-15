import SwiftUI

/// Says the reader awaits a book's edition in the app's language: grey
/// binoculars in the corner, beside the status, as the hidden eye is — on its
/// row and on its page alike.
struct AwaitedMark: View {
    var body: some View {
        Image(systemName: "binoculars")
            .foregroundStyle(.secondary)
            .fixedSize()
            .accessibilityLabel(Text("Suivi"))
    }
}

#Preview {
    AwaitedMark()
        .padding()
}
