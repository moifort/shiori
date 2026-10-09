import SwiftUI

/// The one way an icon sits beside a row's text, on every form and sheet of the
/// app: in a column of fixed width, so glyphs of different widths still line
/// their text up, and level with the first line of text rather than centred on
/// the row, so a field that wraps onto three lines keeps its icon beside its
/// title.
///
/// Applied per screen with `.labelStyle(.row)`, which every `Label` under it
/// inherits — menu items are drawn by the system and keep their own layout.
struct RowLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        RowLabel(configuration: configuration)
    }
}

/// The style's body, a view of its own for the scaled column: held at a fixed
/// width while the glyph grew with the text, it pushed the icon out past the
/// row's left edge at the larger sizes.
private struct RowLabel: View {
    let configuration: LabelStyleConfiguration
    /// Wide enough for the widest symbol the rows use, at every text size.
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 26

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .font(.body)
                .imageScale(.medium)
                // A floor, not a width: at the largest sizes the widest glyphs
                // outgrow even the scaled column, and are better given room
                // than pushed out of the row.
                .frame(minWidth: iconWidth)
            configuration.title
        }
    }
}

extension LabelStyle where Self == RowLabelStyle {
    static var row: RowLabelStyle { RowLabelStyle() }
}

#Preview {
    List {
        Label("Éditeur", systemImage: "building.2")
        Label("Pages", systemImage: "doc.plaintext")
        Label {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sous-genres")
                Text("Fantasy Urbaine, Roman Initiatique, Dark Fantasy, et une ligne de plus")
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: "tag").foregroundStyle(.secondary)
        }
    }
    .labelStyle(.row)
}
