import SwiftUI

/// A row that opens a list, as Settings draws one: a grey symbol, the title,
/// a chevron. Grouped in a rounded card by `LinkRowGroup`.
struct LinkRow: View {
    let symbol: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 50)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Link rows in one rounded card, parted by hairlines under the titles.
struct LinkRowGroup<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            .padding(.horizontal, 20)
    }
}

#Preview {
    LinkRowGroup {
        LinkRow(symbol: "square.grid.3x3", title: "Toute la pile") {}
        Divider().padding(.leading, 54)
        LinkRow(symbol: "hand.thumbsdown", title: "Abandonnés") {}
    }
    .padding(.vertical)
    .background(.black)
    .environment(\.colorScheme, .dark)
}
