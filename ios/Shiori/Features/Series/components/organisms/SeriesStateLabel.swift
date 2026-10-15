import SwiftUI

/// Where the reader stands on a saga, in words — "En cours", "Terminée",
/// "À lire" — as a small tag in the colour of the reading-status badge it
/// matches: blue for reading, green for read, orange for the pile.
struct SeriesStateLabel: View {
    let state: SeriesState

    private var tint: Color {
        switch state {
        case .notStarted: ReadingStatus.toRead.tint
        case .inProgress: ReadingStatus.reading.tint
        case .complete: ReadingStatus.read.tint
        case .unfollowed: .secondary
        }
    }

    var body: some View {
        // A saga set aside says so by the crossed-out bell alone: the word
        // shouted a choice the reader already made.
        if state == .unfollowed {
            Image(systemName: state.symbol)
                .foregroundStyle(.secondary)
                .accessibilityLabel(Text(state.label))
        } else {
            label
        }
    }

    /// Led by the state's symbol — the reading status's own — so the tag reads
    /// like the one on a book row.
    private var label: some View {
        HStack(spacing: 3) {
            Image(systemName: state.symbol)
                .imageScale(.small)
                .accessibilityHidden(true)
            Text(state.label)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tint.opacity(0.15), in: Capsule())
        .fixedSize()
    }
}

#Preview {
    HStack {
        SeriesStateLabel(state: .inProgress)
        SeriesStateLabel(state: .complete)
        SeriesStateLabel(state: .notStarted)
    }
    .padding()
}
