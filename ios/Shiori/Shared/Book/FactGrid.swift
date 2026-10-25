import SwiftUI

/// One fact of a book as a tile, as the TV app's "Informations" sets them: a
/// small caption over the value, chips beside it where the fact has parts — a
/// genre and its subgenres. A tile the page lets the reader correct answers
/// the tap, a chevron after the value where it opens a choice; an unknown
/// value says so, dimmed.
struct FactTile: Identifiable {
    let id: String
    let title: LocalizedStringKey
    /// Nil draws "Non renseigné", dimmed.
    let value: String?
    var chips: [String] = []
    /// A line under the value, in full: what a recommender said of the book.
    var detail: String?
    /// Takes the whole width of the grid rather than a column.
    var isWide = false
    var valueFont: Font = .body.weight(.semibold)
    /// What an unknown value reads as: "Non renseigné" for a fact, a dash
    /// for a day not reached yet.
    var placeholder: String = String(localized: "Non renseigné")
    /// A chevron after the value, for a tile that opens a choice of its own
    /// — the genre — rather than a field to type in.
    var showsChevron = false
    var action: (() -> Void)?
}

/// A way out of Shiori at the foot of the grid, across its width: the
/// service's logo in the text's colour, what the tap does, and the arrow that
/// says it leaves the app.
struct FactLink: Identifiable {
    let id: String
    let title: LocalizedStringKey
    /// The service's logo in the asset catalogue, as a template image.
    let logo: String
    let url: URL
}

/// Tiles laid out so many to a row: two for a book's facts, three for the
/// reading's days.
struct FactGroup {
    let tiles: [FactTile]
    var columns = 2
}

/// Facts as one grid of tiles parted by hairlines and bordered by one: groups
/// laid one under the other, each so many to a row — the reading's three days
/// over the facts two by two — a wide tile alone on its row and a last odd
/// tile across the width, so the grid never ends on a hole.
struct FactGrid: View {
    let groups: [FactGroup]
    var links: [FactLink] = []

    init(groups: [FactGroup], links: [FactLink] = []) {
        self.groups = groups.filter { !$0.tiles.isEmpty }
        self.links = links
    }

    init(tiles: [FactTile], columns: Int = 2) {
        self.init(groups: [FactGroup(tiles: tiles, columns: columns)])
    }

    private static let cornerRadius: CGFloat = 14

    /// The grid's own columns, which every group's divides: six for rows of
    /// two and of three.
    private var span: Int {
        groups.map(\.columns).reduce(1) { lcm($0, $1) }
    }

    var body: some View {
        let span = span
        Grid(horizontalSpacing: 1, verticalSpacing: 1) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.tiles.enumerated()), id: \.element.id) { index, tile in
                        let width = span / row.columns
                        // The last tile of a short row takes what is left of it.
                        cell(tile)
                            .gridCellColumns(index == row.tiles.count - 1 ? span - width * index : width)
                    }
                }
            }
            ForEach(links) { link in
                GridRow {
                    linkCell(link).gridCellColumns(span)
                }
            }
        }
        .background(Color(.separator))
        .clipShape(.rect(cornerRadius: Self.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Self.cornerRadius)
                .strokeBorder(Color(.separator), lineWidth: 1)
        }
    }

    private struct Row {
        let tiles: [FactTile]
        let columns: Int
    }

    /// Each group's tiles in rows: a wide one alone, the others `columns` at
    /// a time.
    private var rows: [Row] {
        var rows: [Row] = []
        for group in groups {
            var current: [FactTile] = []
            for tile in group.tiles {
                if tile.isWide {
                    if !current.isEmpty { rows.append(Row(tiles: current, columns: group.columns)); current = [] }
                    rows.append(Row(tiles: [tile], columns: 1))
                } else {
                    current.append(tile)
                    if current.count == group.columns {
                        rows.append(Row(tiles: current, columns: group.columns))
                        current = []
                    }
                }
            }
            if !current.isEmpty { rows.append(Row(tiles: current, columns: group.columns)) }
        }
        return rows
    }

    private func lcm(_ a: Int, _ b: Int) -> Int {
        func gcd(_ a: Int, _ b: Int) -> Int { b == 0 ? a : gcd(b, a % b) }
        return a / gcd(a, b) * b
    }

    @ViewBuilder
    private func cell(_ tile: FactTile) -> some View {
        let content = VStack(alignment: .leading, spacing: 5) {
            Text(tile.title)
                .font(.footnote)
                .textCase(.uppercase)
                .tracking(0.3)
                .foregroundStyle(.secondary)
            if tile.chips.isEmpty {
                value(tile)
            } else {
                // The parts beside the value, wrapping under it when they
                // run out of room: "Science-fiction › [Post-apocalyptique]".
                PillFlow(spacing: 8) {
                    value(tile)
                    ForEach(tile.chips, id: \.self) { chip in
                        Pill(text: chip, font: .caption.weight(.semibold))
                    }
                }
            }
            if let detail = tile.detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

    private func linkCell(_ link: FactLink) -> some View {
        Link(destination: link.url) {
            HStack(spacing: 12) {
                // One box for both marks, wide enough for Amazon's smile
                // and tall enough for Audible's book.
                Image(link.logo)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 22)
                Text(link.title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("book-store-link-\(link.id)")
    }

    private func value(_ tile: FactTile) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Text(tile.value ?? tile.placeholder)
                .font(tile.value == nil ? .body : tile.valueFont)
                .foregroundStyle(tile.value == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.primary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            if tile.showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
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
            FactGrid(groups: [
                FactGroup(tiles: [
                    FactTile(id: "added", title: "Ajouté", value: "3 sept."),
                    FactTile(id: "started", title: "Commencé", value: "28 sept."),
                    FactTile(id: "finished", title: "Terminé", value: nil),
                ], columns: 3),
                FactGroup(tiles: [
                    FactTile(id: "format", title: "Format", value: "Livre · papier"),
                    FactTile(id: "publisher", title: "Éditeur", value: "Bragelonne"),
                    FactTile(id: "first-published", title: "Parution", value: "2007"),
                ]),
            ], links: [
                FactLink(id: "audible", title: "Écouter sur Audible", logo: "audible-logo", url: URL(string: "https://www.audible.fr")!),
                FactLink(id: "amazon", title: "Voir sur Amazon", logo: "amazon-logo", url: URL(string: "https://www.amazon.fr")!),
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
