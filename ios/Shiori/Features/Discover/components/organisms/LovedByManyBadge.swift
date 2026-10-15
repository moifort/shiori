import SwiftUI

/// The flame a suggestion many friends love carries in its corner.
struct LovedByManyBadge: View {
    var body: some View {
        Image(systemName: "flame.fill")
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(.orange, in: .circle)
            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
            .accessibilityLabel("Adoré par vos amis")
    }
}

#Preview {
    LovedByManyBadge()
        .padding()
}
