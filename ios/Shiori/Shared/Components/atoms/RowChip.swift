import SwiftUI

/// The small tinted capsule a list row draws its tags in — genre, subgenre,
/// status, saga — smaller than a `Pill`, which is sized for a detail screen.
struct RowChip: View {
    let text: String
    let tint: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .foregroundStyle(tint)
        .background(tint.opacity(0.15), in: Capsule())
    }
}

#Preview {
    HStack {
        RowChip(text: "Fantasy", tint: .purple)
        RowChip(text: "Tome 2", tint: .blue, systemImage: "books.vertical")
    }
    .padding()
}
