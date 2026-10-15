import SwiftUI

/// An awaited edition drawn as a saga's next volume is: the cover, the format
/// awaited over the title, when it comes in orange — or "Disponible" in green —
/// and the calendar leaf on the trailing edge while it is still to come.
struct AwaitedEditionReleaseRow: View {
    let edition: AwaitedEdition

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            BookCover(book: edition.cover)
            VStack(alignment: .leading, spacing: 3) {
                Text(edition.format.awaitedTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(edition.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
                // The day still to come is the calendar leaf's to say.
                if edition.announcedDate == nil {
                    Text(edition.stateLine)
                        .foregroundStyle(edition.stateTint.map(AnyShapeStyle.init) ?? AnyShapeStyle(.secondary))
                        .font(.subheadline.weight(.medium))
                }
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 8)
            // Only what is still to come: once out, the green line says it.
            if let date = edition.announcedDate {
                ReleaseDateBadge(date: date)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        AwaitedEditionReleaseRow(edition: .preview)
    }
}
