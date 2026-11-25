import SwiftUI

/// Every book of the export, to tick through, as the shelf photo's review
/// lists its books. A held book stays in the list, untappable, so it does not
/// read as one the import lost; an uncertain one opens the "same book?" sheet.
/// Pure and previewable.
struct GoodreadsBooksPage: View {
    enum Filter: Hashable, CaseIterable {
        case all, new, uncertain, held
    }

    let preview: GoodreadsPreview
    @Binding var choices: GoodreadsChoices
    @State var filter: Filter
    var onDecide: (GoodreadsRow) -> Void

    var body: some View {
        List {
            ForEach(rows) { row in
                Button {
                    toggle(row)
                } label: {
                    line(row)
                }
                .tint(.primary)
                .disabled(row.verdict == .held)
            }
        }
        .listStyle(.plain)
        .safeAreaInset(edge: .top) {
            Picker("Filtre", selection: $filter) {
                Text("Tous").tag(Filter.all)
                Text("À vérifier · \(preview.uncertainRows.count)").tag(Filter.uncertain)
                Text("Déjà chez vous").tag(Filter.held)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .background(.bar)
        }
        .navigationTitle("Livres")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Tout sélectionner") { selectAll(true) }
                    Button("Tout désélectionner") { selectAll(false) }
                } label: {
                    Label("Options", systemImage: "ellipsis")
                }
            }
        }
    }

    private var rows: [GoodreadsRow] {
        switch filter {
        case .all: preview.rows
        case .new: preview.newRows
        case .uncertain: preview.uncertainRows
        case .held: preview.heldRows
        }
    }

    private func toggle(_ row: GoodreadsRow) {
        if row.verdict == .uncertain {
            onDecide(row)
        } else if choices.keys.contains(row.key) {
            choices.keys.remove(row.key)
        } else {
            choices.keys.insert(row.key)
        }
    }

    private func selectAll(_ selected: Bool) {
        for row in preview.rows where row.verdict == .new {
            if selected { choices.keys.insert(row.key) } else { choices.keys.remove(row.key) }
        }
    }

    private func line(_ row: GoodreadsRow) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tick(row))
                .font(.title3)
                .foregroundStyle(row.verdict == .held ? Color.secondary : Color.primary)
                .accessibilityHidden(true)
            BookCover(book: row.heldCover ?? row.cover, width: 32, showsFormatBadge: false)
            VStack(alignment: .leading, spacing: 2) {
                if row.verdict == .uncertain && !choices.keys.contains(row.key) {
                    Text("Peut-être déjà chez vous")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                    Text(verbatim: "\(row.heldTitle ?? row.title) · \(row.authors.first ?? "")")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(row.title)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Text(verbatim: subtitle(row))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Text(row.verdict == .held ? String(localized: "Déjà chez vous") : row.caption(toRead: choices.toRead))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill), in: .capsule)
        }
        .opacity(row.verdict == .held ? 0.55 : 1)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(_ row: GoodreadsRow) -> String {
        let author = row.authors.first ?? ""
        guard let volume = row.volume else { return author }
        return "\(author) · \(String(localized: "Tome \(volume)"))"
    }

    private func tick(_ row: GoodreadsRow) -> String {
        if row.verdict == .held { return "circle" }
        return choices.keys.contains(row.key) ? "checkmark.circle.fill" : "circle"
    }
}

#Preview {
    @Previewable @State var choices = GoodreadsChoices(preview: .preview)
    NavigationStack {
        GoodreadsBooksPage(preview: .preview, choices: $choices, filter: .all, onDecide: { _ in })
    }
    .environment(\.colorScheme, .dark)
}
