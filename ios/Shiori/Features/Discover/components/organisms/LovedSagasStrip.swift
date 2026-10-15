import SwiftUI

/// The Series shelf's strip: the first volume's cover, the saga's name and how
/// many volumes the friend holds, the friend under it.
struct LovedSagasStrip: View {
    let sagas: [LovedSaga]
    let onTapped: (LovedSaga) -> Void

    var body: some View {
        PicksStrip {
            ForEach(sagas) { loved in
                Button { onTapped(loved) } label: { card(loved) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("discover-friend-saga")
            }
        }
    }

    private func card(_ loved: LovedSaga) -> some View {
        let width: CGFloat = 84
        return VStack(alignment: .leading, spacing: 4) {
            if let first = loved.saga.volumes.first {
                BookCover(book: first, width: width, formatBadgeSize: CoverTile.formatBadgeSize)
            }
            Text(loved.saga.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            Text("^[\(loved.saga.ownedCount) tome](inflect: true)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(loved.lovers.caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: width, alignment: .leading)
        .overlay(alignment: .topLeading) {
            if loved.lovers.lovedByMany {
                LovedByManyBadge().offset(x: -6, y: -6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(loved.saga.name), \(loved.lovers.caption)")
    }
}

#Preview {
    List {
        LovedSagasStrip(sagas: FriendPicks.preview.sagas) { _ in }
    }
}
