import SwiftUI

/// Why a book was suggested, as a card over the colours of the reader's book
/// it draws on, as the home's "En cours" card sets its text over a cover: the
/// title in the corner, the reader's covers stacked beside the reason, then
/// each book it cites as a capsule row — the title, the reader's heart or
/// stars, a chevron — that opens the book or its saga.
struct SuggestionReasonCard: View {
    let reason: String
    let references: [SuggestionReference]
    let onOpen: (SuggestionReference) -> Void

    private static let rowHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pourquoi ce livre")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, -2)
            HStack(alignment: .top, spacing: covers.count > 1 ? 14 : 20) {
                if !covers.isEmpty {
                    coverStack
                }
                // The summary's size: the card reads as the page's first text.
                Text(reason)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("suggestion-reason")
            }
            if !references.isEmpty {
                VStack(spacing: 8) {
                    ForEach(references) { reference in
                        row(reference)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .background {
            // Darkened past the hero's veil: a pale cover — a white Folio —
            // blurs to a washed grey the white text and glass rows fade into.
            CoverBackdrop(url: references.lazy.compactMap(\.coverURL).first, ground: .clear)
                .overlay(Color.black.opacity(0.4))
        }
        .clipShape(.rect(cornerRadius: 18))
    }

    /// The reader's own covers, two at most, the first in front and the
    /// second tilted behind it.
    private var covers: [SuggestionReference] {
        Array(references.filter { $0.coverURL != nil }.prefix(2))
    }

    /// A cover alone, set apart from the text, narrows the reason to four
    /// lines as tall as the cover; two stacked keep their room to fan out.
    private var coverWidth: CGFloat { 64 }

    private var coverStack: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(covers.enumerated().reversed()), id: \.element.id) { index, reference in
                BookCover(book: reference.cover, width: coverWidth, showsFormatBadge: false)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                    .rotationEffect(index == 0 ? .zero : .degrees(6))
                    .brightness(index == 0 ? 0 : -0.12)
                    .offset(x: index == 0 ? 0 : 10, y: index == 0 && covers.count > 1 ? 12 : 0)
            }
        }
        .frame(
            width: covers.count > 1 ? coverWidth + 10 : coverWidth,
            height: covers.count > 1 ? 108 : coverWidth * 1.5,
            alignment: .topLeading
        )
        .accessibilityHidden(true)
    }

    private func row(_ reference: SuggestionReference) -> some View {
        Button { onOpen(reference) } label: {
            HStack(spacing: 10) {
                Text(reference.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                mark(reference)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.55))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.white)
            .padding(.leading, 18)
            .padding(.trailing, 14)
            .frame(height: Self.rowHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        // Drawn rather than system glass, whose vibrancy greys the row over a
        // pale backdrop and turns the heart pink.
        .background {
            Capsule()
                .fill(LinearGradient(
                    colors: [.white.opacity(0.2), .white.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 4)
        }
        .accessibilityIdentifier("suggestion-reference")
    }

    /// The heart for a favourite, else the stars, white as the hero's rating
    /// button draws them — the saga's when the book has none of its own.
    @ViewBuilder private func mark(_ reference: SuggestionReference) -> some View {
        if reference.favorite {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .accessibilityLabel(Text("Favori"))
        } else if let rating = reference.rating {
            RatingStars(rating: rating, font: .caption2, monochrome: true)
        }
    }
}

#Preview {
    ScrollView {
        SuggestionReasonCard(
            reason: Suggestion.preview.reason,
            references: Suggestion.preview.references
        ) { _ in }
        .padding(20)
    }
    .background(.black)
}
