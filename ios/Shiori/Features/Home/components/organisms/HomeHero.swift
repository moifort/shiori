import SwiftUI

/// The top of the home screen, as the TV app opens on what it puts forward: the
/// page's name and the day, then the month's discovery over its cover's
/// colours — its cover, why it was chosen, and the way to it on Liquid Glass.
/// Laid wide, on an unfolded iPhone Duo, the month's other discoveries stand in
/// a column on the right. Without a discovery, the name and the day alone, on
/// the page.
struct HomeHero: View {
    /// The month's discoveries, the first put forward. Nil or empty draws the
    /// heading alone.
    let discoveries: [Suggestion]
    let date: Date
    /// Room for the month's other discoveries beside the first.
    var isWide = false
    let onOpen: (Suggestion) -> Void
    let onShowAll: () -> Void

    var body: some View {
        if let lead = discoveries.first {
            VStack(alignment: .leading, spacing: 14) {
                heading
                HStack(alignment: .bottom, spacing: 24) {
                    feature(lead)
                    if isWide, discoveries.count > 1 {
                        others(Array(discoveries.dropFirst().prefix(3)))
                            .frame(width: 250, alignment: .leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, CoverBackdrop.fadeHeight + 4)
            .environment(\.colorScheme, .dark)
            .background {
                CoverBackdrop(url: lead.coverURL)
                    // Up under the bars, the toolbar's glass floating over it.
                .padding(.top, -400)
            }
        } else {
            heading
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)
        }
    }

    private var heading: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("Accueil")
                .font(.largeTitle.weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func feature(_ suggestion: Suggestion) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { onOpen(suggestion) } label: {
                HStack(alignment: .bottom, spacing: 16) {
                    BookCover(book: suggestion.tile, width: isWide ? 120 : 100)
                        .shadow(color: .black.opacity(0.45), radius: 16, y: 10)
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Découverte du mois", systemImage: "sparkles")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.75))
                        Text(suggestion.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)
                            .minimumScaleFactor(0.8)
                        Text(suggestion.authors.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .lineLimit(1)
                        Text(suggestion.reason)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-discovery")

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button { onOpen(suggestion) } label: {
                        Label("Découvrir", systemImage: "sparkles")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                    Button(action: onShowAll) {
                        Text("Tout voir")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glass)
                }
                .controlSize(.large)
            }
        }
    }

    /// The month's other discoveries, as small covers with what they are like.
    private func others(_ suggestions: [Suggestion]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aussi ce mois-ci")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.75))
            ForEach(suggestions) { suggestion in
                Button { onOpen(suggestion) } label: {
                    HStack(spacing: 10) {
                        BookCover(book: suggestion.tile, width: 34, showsFormatBadge: false)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(suggestion.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                            Text(suggestion.short)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.65))
                        }
                        .lineLimit(1)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

extension Suggestion {
    /// The suggestion as a cover draws it.
    var tile: Book {
        Book(
            id: "suggestion-\(id)",
            title: title,
            authors: authors,
            format: format == .audiobook ? .audiobook : .book,
            coverURL: coverURL,
            status: .toRead
        )
    }
}

#Preview("Discovery") {
    ScrollView {
        HomeHero(discoveries: MonthlyDiscoveries.preview.suggestions, date: .now, onOpen: { _ in }, onShowAll: {})
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Wide", traits: .fixedLayout(width: 859, height: 400)) {
    ScrollView {
        HomeHero(discoveries: MonthlyDiscoveries.preview.suggestions, date: .now, isWide: true, onOpen: { _ in }, onShowAll: {})
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("No discovery") {
    HomeHero(discoveries: [], date: .now, onOpen: { _ in }, onShowAll: {})
}
