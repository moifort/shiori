import SwiftUI

/// The label of a shelf's filter menu in the toolbar: the shelf shown, named
/// with its symbol — a bare funnel did not say which one the list was
/// narrowed to. Spelled out rather than a Label, which the toolbar strips
/// down to its icon, and at a size under the toolbar's own, so the pill sits
/// level with the views beside it rather than outweighing them.
struct ShelfFilterLabel: View {
    let symbol: String
    let title: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .imageScale(.small)
            Text(title)
        }
        .font(.subheadline.weight(.medium))
        .padding(.horizontal, 4)
    }
}
