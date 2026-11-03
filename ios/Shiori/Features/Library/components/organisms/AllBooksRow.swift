import SwiftUI

/// The row that opens every book, as Music and TV draw their library rows:
/// a plain symbol, the title, a chevron, and a hairline under the title. It
/// sits between the bar's title and the format pills, which narrow it too.
struct AllBooksRow: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                Text(BookShelf.all.title)
                    .font(.title3)
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .frame(height: 52)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider().padding(.leading, 44)
        }
        .padding(.horizontal, 20)
        .accessibilityIdentifier("library-all-books")
    }
}

#Preview {
    AllBooksRow {}
        .padding(.vertical)
        .background(.black)
        .environment(\.colorScheme, .dark)
}
