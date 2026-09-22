import SwiftUI
import UIKit

/// One piece of text a long press offers to copy, with the words its menu item
/// says it under.
struct CopyableValue {
    let title: LocalizedStringKey
    let value: String
}

extension View {
    /// A long press offers to copy `value`: an ISBN to paste in a bookshop, a
    /// title to search for. A context menu rather than selectable text, which a
    /// list row does not offer and a button row would swallow.
    func copyable(_ value: String) -> some View {
        copyable([CopyableValue(title: "Copier", value: value)])
    }

    /// The same for a row that holds several values — a title and its author
    /// side by side: one menu item each, and none for a value left empty.
    func copyable(_ values: [CopyableValue]) -> some View {
        contextMenu {
            ForEach(Array(values.enumerated()), id: \.offset) { _, entry in
                if !entry.value.isEmpty {
                    Button(entry.title, systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = entry.value
                    }
                }
            }
        }
    }
}
