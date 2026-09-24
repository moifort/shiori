import SwiftUI

/// A wait drawn as a search: a magnifying glass sweeping back and forth over
/// a book, both SF Symbols so the drawing keeps the system's weight, colours
/// and dark mode without an image of its own. The glass is tinted, the book
/// hierarchical grey, as an active control sits on a passive one everywhere
/// in iOS. Still when the reader asked for reduced motion.
struct ScanningBookLoader: View {
    let title: LocalizedStringKey

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sweeping = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 60, weight: .regular))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.tint)
                    // Across the book, corner to corner, and back: what a
                    // reader does with a glass over a page.
                    .offset(x: sweeping ? 16 : -16, y: sweeping ? 12 : -12)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: sweeping
                    )
            }
            .frame(width: 96, height: 96)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .onAppear { sweeping = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.updatesFrequently)
    }
}

#Preview {
    ScanningBookLoader(title: "Recherche des prochaines sorties…")
}
