import SwiftUI

/// The top of the home screen on a phone, as the TV app opens: the month's
/// discoveries one page each, swiped sideways, every page over its own cover's
/// colours — the cover, the title, why it was chosen, the way to it and the
/// "+" that adds or awaits it, on Liquid Glass — with the dots that say where
/// the reader stands. It runs up under the bars, which stay empty until the
/// page is scrolled, and stops short enough for the rows to show under it.
struct HomeDiscoveryCarousel: View {
    /// The month's discoveries, never empty.
    let discoveries: [Suggestion]
    let onOpen: (Suggestion) -> Void
    let onAdd: (Suggestion, ReadingStatus) -> Void
    let onAwait: (Suggestion, ReleaseFormat) -> Void

    @State private var current: Suggestion.ID?

    /// How tall the carousel stands.
    static let height: CGFloat = 490
    /// How far it runs up under the empty bar: the cover starts just under
    /// the status bar, as the TV app's artwork does.
    private static let barOverlap: CGFloat = 50
    /// How tall the fade into the page is: long and eased, so the colours
    /// melt into it rather than stop at a line.
    private static let fadeHeight: CGFloat = 240

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(discoveries) { suggestion in
                    page(suggestion)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        // The backdrops run up under the bars, past the pager's frame.
        .scrollClipDisabled()
        .frame(height: Self.height)
        .overlay(alignment: .bottom) {
            if discoveries.count > 1 {
                PageDots(count: discoveries.count, index: currentIndex)
                    .padding(.bottom, 12)
            }
        }
        .padding(.top, -Self.barOverlap)
        .accessibilityIdentifier("home-discovery")
    }

    private var currentIndex: Int {
        discoveries.firstIndex { $0.id == current } ?? 0
    }

    private func page(_ suggestion: Suggestion) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            Button { onOpen(suggestion) } label: {
                VStack(spacing: 0) {
                    BookCover(book: suggestion.tile, width: 140)
                        .shadow(color: .black.opacity(0.5), radius: 22, y: 14)
                    Text("Découverte du mois")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.clear, in: .capsule)
                        .padding(.top, 18)
                    Text(suggestion.title)
                        .font(.title.weight(.bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 10)
                    Text(meta(suggestion))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .padding(.top, 4)
                    Text(suggestion.reason)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button { onOpen(suggestion) } label: {
                        Label("Découvrir", systemImage: "sparkles")
                            .font(.headline)
                            .frame(width: 170)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    Menu {
                        SuggestionAddActions(
                            suggestion: suggestion,
                            onAdd: { onAdd(suggestion, $0) },
                            onAwait: { onAwait(suggestion, $0) }
                        )
                    } label: {
                        Label("Ajouter", systemImage: "plus")
                            .labelStyle(.iconOnly)
                            .font(.headline)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .accessibilityIdentifier("home-discovery-menu")
                }
                .controlSize(.extraLarge)
            }
            .padding(.top, 16)
        }
        .padding(.horizontal, 28)
        // Room for the dots under the buttons.
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: suggestion.coverURL, fadeHeight: Self.fadeHeight)
                // Up under the bars and the status bar.
                .padding(.top, -400)
        }
    }

    /// Who wrote it and what it is like, as the TV app says a film's genres.
    private func meta(_ suggestion: Suggestion) -> String {
        ([suggestion.authors.joined(separator: ", "), suggestion.short].filter { !$0.isEmpty })
            .joined(separator: " · ")
    }
}

/// Where the reader stands among a carousel's pages: a dot each, the current
/// one drawn long.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 7) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(.white.opacity(page == index ? 0.95 : 0.4))
                    .frame(width: page == index ? 22 : 7, height: 7)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(index + 1) sur \(count)"))
    }
}

#Preview {
    ScrollView {
        HomeDiscoveryCarousel(
            discoveries: MonthlyDiscoveries.preview.suggestions,
            onOpen: { _ in },
            onAdd: { _, _ in },
            onAwait: { _, _ in }
        )
        Color.clear.frame(height: 600)
    }
    .background(Color(.systemGroupedBackground))
}
