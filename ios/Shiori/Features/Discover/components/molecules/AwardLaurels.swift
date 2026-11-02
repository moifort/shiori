import SwiftUI

/// A prize between its laurels: its name, its year, what it crowns. On an
/// image, so always in white.
struct AwardLaurels: View {
    let mention: AwardMention

    var body: some View {
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
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Award laurels") {
    AwardLaurels(mention: AwardMention(award: .hugo, year: 2026))
        .padding()
        .background(.black)
}
