import SwiftUI

/// A row of pills that narrow what is under them, as the TV app filters a
/// shelf: the one chosen in the label's colour, the others on a tile, scrolling
/// sideways past the edge. "Tout" leads and chooses nothing.
struct FilterPills: View {
    struct Pill: Identifiable, Hashable {
        let id: String
        let label: String
    }

    let pills: [Pill]
    /// The pill chosen, nil for the leading "Tout" when there is one.
    let selected: String?
    /// Leads the row with "Tout", which selects nothing.
    var allLabel: String? = String(localized: "Tout")
    let onSelect: (String?) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                if let allLabel {
                    pill(allLabel, isOn: selected == nil) { onSelect(nil) }
                }
                ForEach(pills) { item in
                    pill(item.label, isOn: selected == item.id) { onSelect(item.id) }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
    }

    private func pill(_ label: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 15)
                .frame(height: 34)
                .foregroundStyle(isOn ? Color(.systemBackground) : .primary)
                .background(isOn ? Color.primary : Color(.secondarySystemGroupedBackground), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 20) {
        FilterPills(
            pills: [.init(id: "book", label: "Livres"), .init(id: "manga", label: "Mangas"), .init(id: "bd", label: "BD")],
            selected: nil
        ) { _ in }
        FilterPills(
            pills: [.init(id: "all", label: "Toutes"), .init(id: "progress", label: "En cours")],
            selected: "all",
            allLabel: nil
        ) { _ in }
    }
    .padding(.vertical)
    .background(.black)
}
