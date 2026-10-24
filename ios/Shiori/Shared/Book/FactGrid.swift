import SwiftUI

/// One fact of a book as a tile, as Photos' info panel sets them: a small
/// caption over the value, chips under it where the fact has parts — a genre
/// and its subgenres. A tile the page lets the reader correct answers the tap,
/// its value in the tint with a chevron; an unknown value says so, dimmed.
struct FactTile: Identifiable {
    let id: String
    let title: LocalizedStringKey
    /// Nil draws "Non renseigné", dimmed.
    let value: String?
    var chips: [String] = []
    /// Takes the whole width of the grid rather than a column.
    var isWide = false
    var valueFont: Font = .subheadline.weight(.semibold)
    /// What an unknown value reads as: "Non renseigné" for a fact, a dash
    /// for a day not reached yet.
    var placeholder: String = String(localized: "Non renseigné")
    /// A chevron after the value, for a tile that opens a choice of its own
    /// — the genre — rather than a field to type in.
    var showsChevron = false
    var action: (() -> Void)?
}

/// Facts as a grid of tiles parted by hairlines, two to a row — three for the
/// reading's days — a wide tile alone on its row and a last odd tile across
/// the width, so the grid never ends on a hole.
struct FactGrid: View {
    let tiles: [FactTile]
    var columns = 2

    var body: some View {
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.element.id) { index, tile in
                        // The last tile of a short row takes what is left of it.
                        cell(tile)
                            .gridCellColumns(index == row.count - 1 ? columns - row.count + 1 : 1)
                    }
                }
            }
        }
        .background(Color(.separator).opacity(0.6))
        .clipShape(.rect(cornerRadius: 16))
    }

    /// The tiles in rows: a wide one alone, the others `columns` at a time.
    private var rows: [[FactTile]] {
        var rows: [[FactTile]] = []
        var current: [FactTile] = []
        for tile in tiles {
            if tile.isWide {
                if !current.isEmpty { rows.append(current); current = [] }
                rows.append([tile])
            } else {
                current.append(tile)
                if current.count == columns { rows.append(current); current = [] }
            }
        }
        if !current.isEmpty { rows.append(current) }
        return rows
    }

    @ViewBuilder
    private func cell(_ tile: FactTile) -> some View {
        let content = VStack(alignment: .leading, spacing: 4) {
            Text(tile.title)
                .font(.caption2.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.4)
                .foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(tile.value ?? tile.placeholder)
                    .font(tile.value == nil ? .subheadline : tile.valueFont)
                    .foregroundStyle(tile.value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if tile.showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
            }
            if !tile.chips.isEmpty {
                TagList(tags: tile.chips, systemImage: "tag")
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemGroupedBackground))

        if let action = tile.action {
            Button(action: action) { content.contentShape(.rect) }
                .buttonStyle(.plain)
                .copyable(tile.value ?? "")
                .accessibilityIdentifier("book-\(tile.id)")
        } else {
            content
                .copyable(tile.value ?? "")
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("book-\(tile.id)")
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            FactGrid(tiles: [
                FactTile(id: "genre", title: "Genre", value: "Fantasy", chips: ["Roman initiatique", "Aventure"], isWide: true, showsChevron: true, action: {}),
                FactTile(id: "format", title: "Format", value: "Livre · papier"),
                FactTile(id: "publisher", title: "Éditeur", value: "Bragelonne", action: {}),
                FactTile(id: "first-published", title: "Parution", value: "2007", action: {}),
                FactTile(id: "pages", title: "Pages", value: "662", action: {}),
                FactTile(id: "isbn", title: "ISBN", value: nil, action: {}),
            ])
            FactGrid(tiles: [
                FactTile(id: "added", title: "Ajouté", value: "3 sept."),
                FactTile(id: "started", title: "Commencé", value: "28 sept."),
                FactTile(id: "finished", title: "Terminé", value: nil),
            ], columns: 3)
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
