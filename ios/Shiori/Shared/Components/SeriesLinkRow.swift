import SwiftUI

/// The way from a book's page to its saga, as the book page draws it right
/// under the cover: "Série" and the saga's name in the tint, with a chevron.
struct SeriesLinkRow: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label {
                LabeledContent("Série") {
                    HStack(spacing: 4) {
                        Text(name).multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(.tint)
                }
            } icon: {
                Image(systemName: "square.stack").foregroundStyle(.secondary)
            }
        }
        .tint(.primary)
    }
}
