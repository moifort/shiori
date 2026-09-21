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
    /// Wide enough for the widest symbol the rows use at body size.
    static let iconWidth: CGFloat = 26

    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            configuration.icon
                .font(.body)
                .imageScale(.medium)
                .frame(width: Self.iconWidth)
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
