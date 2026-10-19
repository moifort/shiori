import SwiftUI

/// One of the month's first discoveries, drawn whole above the strip: its
/// cover, then the mark of the reader's book it is drawn from, the "comme …"
/// line and why. No title nor author beside it: the cover carries them, and
/// the room is the reason's.
struct DiscoverySuggestionRow: View {
    let suggestion: Suggestion

    private static let coverWidth: CGFloat = 56

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: suggestion.cover, width: Self.coverWidth)
            why
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(5)
                // Its full height: the list row would otherwise hold it to a
                // line or two.
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .contentShape(.rect)
        // The title the cover shows, then why.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: suggestion.title))
        .accessibilityValue(why)
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
