import SwiftUI

/// A prize between its laurels, taller than its lines so they frame it: its
/// name, its year, what it crowns. On an image, so always in white.
struct AwardLaurels: View {
    let mention: AwardMention

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "laurel.leading").font(.system(size: 56))
            VStack(spacing: 1) {
                Text(mention.award.shortName)
                    .font(.system(size: 12, weight: .bold))
                    .textCase(.uppercase)
                    .tracking(1)
                Text(verbatim: String(mention.year))
                    .font(.system(size: 23, weight: .heavy))
                    .monospacedDigit()
                Text(mention.award.categoryName)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Image(systemName: "laurel.trailing").font(.system(size: 56))
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
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

#Preview("Award laurels") {
    AwardLaurels(mention: AwardMention(award: .hugo, year: 2026))
        .padding()
        .background(.black)
}
