import SwiftUI

/// An award's latest winner as the feed announces it: the prize between its
/// laurels, the book, and the buttons to add it or to not be told of it.
struct AwardNewsCard: View {
    let winner: AwardWinner
    let onOpen: () -> Void
    let onAdd: () async -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onOpen) {
                BookCover(book: winner.cover, width: 84)
                    .padding(.vertical, 12)
                    .padding(.leading, 12)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                if let mention = winner.mentions.first {
                    HStack(spacing: 4) {
                        Image(systemName: "laurel.leading").font(.title2)
                        VStack(spacing: 1) {
                            Text(mention.award.shortName)
                                .font(.system(size: 9, weight: .bold))
                                .textCase(.uppercase)
                                .tracking(1)
                            Text(verbatim: String(mention.year))
                                .font(.headline.weight(.heavy))
                                .monospacedDigit()
                            Text(mention.award.categoryName)
                                .font(.system(size: 10))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Image(systemName: "laurel.trailing").font(.title2)
                    }
                    .padding(.bottom, 6)
                }
                Text(winner.title)
                    .font(.headline.weight(.bold))
                    .lineLimit(2)
                Text(winner.authors.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                HStack(spacing: 8) {
                    AsyncButton(action: onAdd) {
                        Label("Ajouter", systemImage: "plus")
                            .font(.footnote.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(height: 30)
                            .background(.white, in: .capsule)
                            .foregroundStyle(.black)
                    }
                    .buttonStyle(.plain)
                    Button(action: onDismiss) {
                        Image(systemName: "hand.thumbsdown")
                            .font(.footnote)
                            .frame(width: 30, height: 30)
                            .background(.white.opacity(0.14), in: .circle)
                            .overlay { Circle().strokeBorder(.white.opacity(0.22)) }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Pas intéressé")
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 12)
            .padding(.trailing, 14)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .background {
            ZStack {
                Color(white: 0.16)
                if let url = winner.coverURL {
                    AsyncImage(url: url) { image in
                        image.resizable().scaledToFill().blur(radius: 30).saturation(1.4)
                    } placeholder: {
                        Color.clear
                    }
                    Color.black.opacity(0.4)
                }
            }
        }
        .clipShape(.rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.18)) }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .accessibilityIdentifier("news-award-card")
    }
}

extension LiteraryAward {
    /// What the prize crowns, under its year.
    var categoryName: String {
        switch self {
        case .locusScienceFiction: String(localized: "Meilleur roman de SF")
        case .locusFantasy: String(localized: "Meilleur roman de fantasy")
        default: String(localized: "Meilleur roman")
        }
    }
}

#Preview("Award news card") {
    AwardNewsCard(winner: .newsPreview, onOpen: {}, onAdd: {}, onDismiss: {})
        .preferredColorScheme(.dark)
}
