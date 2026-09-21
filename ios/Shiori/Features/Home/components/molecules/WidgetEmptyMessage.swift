import SwiftUI

/// What a widget shows in place of figures it does not have yet. Every card is
/// drawn from the very first launch, an empty library included, so the reader
/// sees what the dashboard will hold: a muted sketch of what the card will
/// draw, and under it a line saying what fills it.
struct WidgetEmptyMessage: View {
    let text: LocalizedStringKey
    var placeholder: Placeholder?

    /// The shape of what the card will hold, drawn in the faintest fill.
    enum Placeholder {
        /// A shelf of covers.
        case covers
        /// One book beside its lines of text.
        case book
        /// A few rows of figures.
        case rows
        /// A bar cut into segments.
        case segments
        /// Progress rings, as the series draw theirs.
        case rings
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let placeholder {
                sketch(placeholder)
                    .foregroundStyle(.quaternary)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("widget-empty")
    }

    @ViewBuilder
    private func sketch(_ placeholder: Placeholder) -> some View {
        switch placeholder {
        case .covers:
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .frame(width: 64, height: 96)
                }
            }
        case .book:
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .frame(width: 44, height: 66)
                lines([0.5, 0.8, 0.4])
            }
        case .rows:
            lines([0.7, 0.55])
        case .segments:
            HStack(spacing: 3) {
                ForEach([0.4, 0.25, 0.2, 0.15], id: \.self) { share in
                    Capsule().frame(maxWidth: .infinity).layoutPriority(share)
                }
            }
            .frame(height: 12)
        case .rings:
            HStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { _ in
                    HStack(spacing: 10) {
                        Circle().stroke(lineWidth: 5).frame(width: 34, height: 34)
                        lines([0.9, 0.5]).frame(width: 70)
                    }
                }
            }
        }
    }

    /// Grey bars standing for lines of text, each a share of the width.
    private func lines(_ widths: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, width in
                GeometryReader { proxy in
                    Capsule().frame(width: proxy.size.width * width, height: 9)
                }
                .frame(height: 9)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        WidgetCard(title: "En cours") {
            WidgetEmptyMessage(text: "Aucun livre en cours de lecture.", placeholder: .covers)
        }
        WidgetCard(title: "Dernier livre terminé") {
            WidgetEmptyMessage(text: "Terminez un livre pour le retrouver ici.", placeholder: .book)
        }
        WidgetCard(title: "Genres") {
            WidgetEmptyMessage(text: "Terminez un livre cette année pour voir vos genres.", placeholder: .segments)
        }
        WidgetCard(title: "Séries en cours") {
            WidgetEmptyMessage(text: "Aucune série en cours.", placeholder: .rings)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
