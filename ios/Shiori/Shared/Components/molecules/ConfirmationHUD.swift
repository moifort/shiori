import SwiftUI

/// A brief word in the middle of the screen once something is done, as macOS
/// says it: a large symbol over a short line, on a square that blurs what lies
/// beneath rather than darkening it. It shows, holds, and fades by itself;
/// nothing in it can be tapped.
struct ConfirmationHUD: View {
    let symbol: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 56, weight: .medium))
                .frame(height: 64)
            Text(label)
                .font(.callout.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 18)
        }
        .foregroundStyle(.white)
        .frame(width: 190, height: 190)
        .background {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(.white.opacity(0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 0.5)
                }
        }
        .environment(\.colorScheme, .dark)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

extension View {
    /// Shows `confirmation`'s HUD over the screen while it is set, and clears
    /// it after a moment.
    func confirmationHUD(_ confirmation: Binding<Confirmation?>) -> some View {
        overlay {
            if let shown = confirmation.wrappedValue {
                ConfirmationHUD(symbol: shown.symbol, label: shown.label)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .task(id: shown.id) {
                        try? await Task.sleep(for: .seconds(1.6))
                        guard confirmation.wrappedValue?.id == shown.id else { return }
                        withAnimation(.easeOut(duration: 0.3)) { confirmation.wrappedValue = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.3), value: confirmation.wrappedValue?.id)
    }
}

/// What the HUD says, and with which symbol.
struct Confirmation: Identifiable, Equatable {
    let id = UUID()
    let symbol: String
    let label: LocalizedStringKey

    static func == (lhs: Confirmation, rhs: Confirmation) -> Bool { lhs.id == rhs.id }

    /// The book went onto the shelf, whatever its status.
    static var addedToLibrary: Confirmation {
        Confirmation(symbol: "book", label: "Ajouté à la bibliothèque")
    }

    /// The book went onto the wishlist.
    static var addedToWishlist: Confirmation {
        Confirmation(symbol: "bookmark", label: "Ajouté à la liste d'envies")
    }

    /// An edition is awaited: it shows on the wishlist among those awaited,
    /// under the binoculars the app gives every awaited edition.
    static var awaited: Confirmation {
        Confirmation(symbol: "binoculars", label: "Ajouté à la liste d'envies")
    }
}

#Preview("Bibliothèque") {
    ZStack {
        LinearGradient(colors: [.indigo, .black], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
        ConfirmationHUD(symbol: Confirmation.addedToLibrary.symbol, label: Confirmation.addedToLibrary.label)
    }
}

#Preview("Envies") {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfirmationHUD(symbol: Confirmation.addedToWishlist.symbol, label: Confirmation.addedToWishlist.label)
    }
}

#Preview("Guettée") {
    ZStack {
        Color.black.ignoresSafeArea()
        ConfirmationHUD(symbol: Confirmation.awaited.symbol, label: Confirmation.awaited.label)
    }
}
