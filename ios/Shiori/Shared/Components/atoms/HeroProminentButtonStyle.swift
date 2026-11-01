import SwiftUI

/// The white call to action of a hero, on Liquid Glass that does not react to
/// the touch: `.glassProminent` swells under a finger pressing a menu row lying
/// over it, as if it had been tapped. The press is drawn here, and only for a
/// touch the button really takes.
struct HeroProminentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .frame(height: 52)
            .contentShape(.capsule)
            .glassEffect(.regular.tint(.white), in: .capsule)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == HeroProminentButtonStyle {
    static var heroProminent: HeroProminentButtonStyle { HeroProminentButtonStyle() }
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
