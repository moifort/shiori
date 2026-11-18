import SwiftUI

/// The white call to action of a hero: the shared action style at the hero's
/// 52 pt, so it sinks and springs back under the finger like every other
/// action button (`ActionButtonStyle`).
extension ButtonStyle where Self == ActionButtonStyle {
    static var heroProminent: ActionButtonStyle { ActionButtonStyle(fill: .white, height: 52) }
}

#Preview {
    Button {} label: {
        Label("Découvrir", systemImage: "sparkles")
            .font(.headline)
            .frame(maxWidth: .infinity)
    }
    .buttonStyle(.heroProminent)
    .padding()
    .background(.gray)
}
