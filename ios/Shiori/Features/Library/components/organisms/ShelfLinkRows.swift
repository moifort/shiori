import SwiftUI

/// The shelves that close the entry screen, grouped as Settings rows: every
/// book, and those given up on when there are some.
struct ShelfLinkRows: View {
    var showsDropped: Bool
    let onOpen: (BookShelf) -> Void

    var body: some View {
        VStack(spacing: 0) {
            row(.all, symbol: "square.grid.3x3")
            if showsDropped {
                Divider().padding(.leading, 54)
                row(.dropped, symbol: "nosign")
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .padding(.horizontal, 20)
    }

    private func row(_ shelf: BookShelf, symbol: String) -> some View {
        Button { onOpen(shelf) } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 26)
                Text(shelf.title)
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

#Preview {
    ShelfLinkRows(showsDropped: true) { _ in }
        .padding(.vertical)
        .background(.black)
        .environment(\.colorScheme, .dark)
}
