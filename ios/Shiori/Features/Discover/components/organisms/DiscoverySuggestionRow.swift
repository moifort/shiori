import SwiftUI

/// One of the month's first discoveries, drawn whole above the strip: its
/// cover, its title, then the mark of the reader's book it is drawn from, the
/// "comme …" line and why. No author: the room is the reason's.
struct DiscoverySuggestionRow: View {
    let suggestion: Suggestion

    private static let coverWidth: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: suggestion.cover, width: Self.coverWidth)
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                why
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
    }

    /// "♥ comme **Gagner la guerre** — un héros rusé…": the lead reference's
    /// mark, the line in bold, the reason.
    private var why: Text {
        let mark: Text = if let lead = suggestion.leadReference {
            lead.favorite
                ? Text(Image(systemName: "heart.fill")).foregroundStyle(.red)
                : Text(Image(systemName: "star.fill")).foregroundStyle(.yellow)
        } else {
            Text(Image(systemName: "sparkles")).foregroundStyle(.purple)
        }
        return Text("\(mark) \(Text(suggestion.short).bold().foregroundStyle(.primary)) — \(suggestion.reason)")
    }
}

#Preview {
    List {
        ForEach(MonthlyDiscoveries.preview.suggestions.prefix(2)) { suggestion in
            DiscoverySuggestionRow(suggestion: suggestion)
        }
    }
}
