import SwiftUI

/// The rows that open the library's lists, as Music and TV draw their
/// library rows: a plain symbol, the title, a chevron, and a hairline under
/// the title. They sit between the bar's title and the format pills, which
/// narrow them too. A list with nothing in it offers no row, but for the
/// wishlist, whose empty page says how to fill it.
struct LibraryLinkRows: View {
    var showsSeries = true
    var showsAuthors = true
    var showsNarrators = true
    let onAction: (LibraryShelvesAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            LibraryLinkRow(symbol: "books.vertical", title: String(localized: "Livres")) {
                onAction(.openShelf(.all))
            }
            .accessibilityIdentifier("library-all-books")
            if showsSeries {
                LibraryLinkRow(symbol: "square.stack", title: String(localized: "Séries")) {
                    onAction(.openSeriesShelf)
                }
            }
            if showsAuthors {
                // The app's own quill (`Assets.xcassets/author`), drawn for the
                // author everywhere the app names one.
                LibraryLinkRow(image: Image("author"), title: String(localized: "Auteurs")) {
                    onAction(.openAuthors)
                }
            }
            if showsNarrators {
                LibraryLinkRow(symbol: "mic", title: String(localized: "Narrateurs")) {
                    onAction(.openNarrators)
                }
            }
            // Always offered: an empty wishlist says how to fill it.
            LibraryLinkRow(symbol: "gift", title: String(localized: "Liste d'envies")) {
                onAction(.openWishlist)
            }
            .accessibilityIdentifier("library-wishlist")
        }
        .padding(.horizontal, 20)
    }
}

/// One of the library's rows: the symbol, the title, the chevron, the hairline.
private struct LibraryLinkRow: View {
    let image: Image
    let title: String
    let action: () -> Void

    init(image: Image, title: String, action: @escaping () -> Void) {
        self.image = image
        self.title = title
        self.action = action
    }

    init(symbol: String, title: String, action: @escaping () -> Void) {
        self.init(image: Image(systemName: symbol), title: title, action: action)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                image
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .frame(width: 28)
                Text(title)
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
    }
}

#Preview {
    LibraryLinkRows { _ in }
        .padding(.vertical)
        .background(.black)
        .environment(\.colorScheme, .dark)
}
