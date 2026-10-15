import SwiftUI

/// The challenge as the Partagé tab draws it: the verdict on top, then the
/// podium and the rest as bars measured against the leader.
struct ReadingChallengeCard: View {
    let challenge: ReadingChallenge

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let verdict = challenge.verdict
            Label {
                Text(verdict.text)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: verdict.symbol)
                    .foregroundStyle(.orange)
                    .symbolEffect(.bounce, value: verdict.text)
            }
            VStack(spacing: 8) {
                ForEach(challenge.visible) { entry in
                    row(entry)
                }
            }
        }
        .padding(.vertical, 6)
        .accessibilityIdentifier("shared-reading-challenge")
    }

    private func row(_ entry: ReadingChallenge.Entry) -> some View {
        HStack(spacing: 10) {
            Text(medal(entry.rank))
                .font(entry.rank <= 3 ? .title3 : .subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 28)
            Text(entry.name)
                .font(.subheadline.weight(entry.isMe ? .semibold : .regular))
                .foregroundStyle(entry.isMe ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary))
                .lineLimit(1)
                .frame(width: 84, alignment: .leading)
            GeometryReader { proxy in
                Capsule()
                    .fill(entry.isMe ? AnyShapeStyle(.tint) : AnyShapeStyle(.orange.opacity(0.55)))
                    .frame(width: barWidth(entry, in: proxy.size.width))
                    .frame(maxHeight: .infinity)
            }
            .frame(height: 10)
            Text("\(entry.count)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .frame(minWidth: 24, alignment: .trailing)
                .contentTransition(.numericText())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityText(entry)))
    }

    private func medal(_ rank: Int) -> String {
        switch rank {
        case 1: "🥇"
        case 2: "🥈"
        case 3: "🥉"
        default: "\(rank)."
        }
    }

    /// Measured against the leader; a reader at zero still shows a dot, so the
    /// row reads as a lane rather than a gap.
    private func barWidth(_ entry: ReadingChallenge.Entry, in width: CGFloat) -> CGFloat {
        guard challenge.best > 0 else { return 10 }
        return max(10, width * CGFloat(entry.count) / CGFloat(challenge.best))
    }

    private func accessibilityText(_ entry: ReadingChallenge.Entry) -> String {
        let books = entry.count == 1
            ? String(localized: "1 livre")
            : String(localized: "\(entry.count) livres")
        let place = entry.rank == 1 ? String(localized: "Premier") : String(localized: "\(entry.rank)e")
        return "\(place), \(entry.name), \(books)"
    }
}

#Preview {
    List {
        ReadingChallengeCard(
            challenge: ReadingChallenge(me: Friend(seenByFriends: .preview), friends: Friend.previews)
        )
    }
}
