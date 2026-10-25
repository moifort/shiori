import SwiftUI

/// Why a book was suggested, as a card over the colours of the reader's book
/// it draws on, as the home's "En cours" card sets its text over a cover: the
/// title in the corner, the reader's covers stacked beside the reason, then
/// each book it cites as a row on glass — the genre's symbol in a disc at its
/// leading end, the title, the reader's heart or stars, a chevron — that
/// opens the book or its saga.
struct SuggestionReasonCard: View {
    let reason: String
    let references: [SuggestionReference]
    let onOpen: (SuggestionReference) -> Void

    /// One row's height, which the genre's disc fills.
    private static let rowHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pourquoi ce livre")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.white.opacity(0.75))
                .padding(.bottom, -2)
            HStack(alignment: .top, spacing: 14) {
                if !covers.isEmpty {
                    coverStack
                }
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("suggestion-reason")
            }
            if !references.isEmpty {
                GlassEffectContainer(spacing: 8) {
                    VStack(spacing: 8) {
                        ForEach(references) { reference in
                            row(reference)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: references.lazy.compactMap(\.coverURL).first, ground: .clear)
        }
        .clipShape(.rect(cornerRadius: 18))
    }

    /// The reader's own covers, two at most, the first in front and the
    /// second tilted behind it.
    private var covers: [SuggestionReference] {
        Array(references.filter { $0.coverURL != nil }.prefix(2))
    }

    private var coverStack: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(covers.enumerated().reversed()), id: \.element.id) { index, reference in
                BookCover(book: reference.cover, width: 64, showsFormatBadge: false)
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 6)
                    .rotationEffect(index == 0 ? .zero : .degrees(6))
                    .brightness(index == 0 ? 0 : -0.12)
                    .offset(x: index == 0 ? 0 : 10, y: index == 0 ? 12 : 0)
            }
        }
        .frame(width: covers.count > 1 ? 74 : 64, height: covers.count > 1 ? 108 : 96, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func row(_ reference: SuggestionReference) -> some View {
        Button { onOpen(reference) } label: {
            HStack(spacing: 10) {
                genreDisc(reference.genre)
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
            .padding(.trailing, 14)
            .frame(height: Self.rowHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityIdentifier("suggestion-reference")
    }

    /// The genre's symbol in a disc that fills the row's leading end, flush
    /// with the capsule so only its edge draws a line.
    private func genreDisc(_ genre: BookGenre?) -> some View {
        Circle()
            .fill(.white.opacity(0.14))
            .frame(width: Self.rowHeight, height: Self.rowHeight)
            .overlay {
                (genre?.image ?? Image(systemName: "book.closed"))
                    .font(.body)
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(Text(genre?.label ?? ""))
            .accessibilityHidden(genre == nil)
    }

    /// The heart for a favourite, else the star and the score — the saga's
    /// when the book has none of its own.
    @ViewBuilder private func mark(_ reference: SuggestionReference) -> some View {
        if reference.favorite {
            Image(systemName: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .accessibilityLabel(Text("Favori"))
        } else if let rating = reference.rating {
            HStack(spacing: 3) {
                Image(systemName: "star.fill")
                    .font(.caption)
                Text(rating.formatted(.number.precision(.fractionLength(0...1))))
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("\(rating.formatted(.number.precision(.fractionLength(0...1)))) étoiles"))
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
