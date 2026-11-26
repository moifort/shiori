import SwiftUI

/// The service's logo on a rounded tile, as the Goodreads export page draws
/// it; once connected, a white check badge on its corner.
struct LibraryLogoTile: View {
    let library: OnboardingLibrary
    var isDone = false

    var body: some View {
        Image(library.logo)
            .resizable()
            .scaledToFit()
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .frame(width: 64, height: 64)
            .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 16))
            .overlay(alignment: .bottomTrailing) {
                if isDone {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 26, height: 26)
                        .background(.white, in: .circle)
                        .overlay(Circle().stroke(.black, lineWidth: 3))
                        .offset(x: 6, y: 6)
                }
            }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 24) {
        LibraryLogoTile(library: .audible)
        LibraryLogoTile(library: .kindle, isDone: true)
        LibraryLogoTile(library: .goodreads)
    }
    .padding()
    .environment(\.colorScheme, .dark)
}
