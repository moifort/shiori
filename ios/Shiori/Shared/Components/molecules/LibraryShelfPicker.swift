import SwiftUI

/// The shelves Découvrir and a friend's library are switched between.
enum LibraryShelf: String, CaseIterable, Identifiable {
    case books, series, authors
    var id: String { rawValue }

    var label: String {
        switch self {
        case .books: String(localized: "Livres")
        case .series: String(localized: "Séries")
        case .authors: String(localized: "Auteurs")
        }
    }
}

/// The "Livres | Séries | Auteurs" capsule, in Liquid Glass, centred above the
/// tab bar. `shelves` are the ones offered: a friend's library has no authors.
struct LibraryShelfPicker: View {
    @Binding var shelf: LibraryShelf
    var shelves: [LibraryShelf] = LibraryShelf.allCases

    var body: some View {
        Picker("Rayon", selection: $shelf) {
            ForEach(shelves) { shelf in
                Text(shelf.label).tag(shelf)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: CGFloat(shelves.count) * 110)
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.bottom, 8)
        .accessibilityIdentifier("library-shelf-picker")
    }
}

extension View {
    /// Float the shelf capsule over the bottom of a shelf's root screen. Only
    /// the root: a saga pushed over the list has no business switching shelves.
    @ViewBuilder
    func libraryShelfPicker(
        _ shelf: Binding<LibraryShelf>?,
        shelves: [LibraryShelf] = LibraryShelf.allCases
    ) -> some View {
        if let shelf {
            safeAreaInset(edge: .bottom) { LibraryShelfPicker(shelf: shelf, shelves: shelves) }
        } else {
            self
        }
    }
}

#Preview {
    @Previewable @State var shelf: LibraryShelf = .books
    LibraryShelfPicker(shelf: $shelf)
}
