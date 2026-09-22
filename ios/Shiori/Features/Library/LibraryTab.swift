import SwiftUI

/// The two shelves the Library tab holds.
enum LibraryShelf: String, CaseIterable, Identifiable {
    case books, series
    var id: String { rawValue }

    var label: String {
        switch self {
        case .books: String(localized: "Livres")
        case .series: String(localized: "Séries")
        }
    }
}

/// The Library tab: the books and the sagas, one at a time, switched by a
/// capsule floating just above the tab bar.
///
/// The capsule belongs to this tab alone, which is why it is drawn here rather
/// than as the tab bar's native accessory: that bar is app-wide by design,
/// hiding it for one tab needs iOS 26.1, and it misbehaves when shown
/// conditionally under a selectable `TabView`. Each shelf keeps its own stack,
/// toolbar and cache; the one last shown comes back on the next launch.
struct LibraryTab: View {
    let onAdd: () -> Void
    @Binding var libraryRequest: LibraryRequest?
    @Binding var seriesRequest: SeriesRequest?

    @AppStorage("library-shelf") private var shelf: LibraryShelf = .books

    var body: some View {
        Group {
            switch shelf {
            case .books:
                LibraryView(onAdd: onAdd, requestedMode: $libraryRequest, shelf: $shelf)
            case .series:
                SeriesListView(onScan: onAdd, requested: $seriesRequest, shelf: $shelf)
            }
        }
        // Another tab asking for a view of one shelf brings that shelf forward;
        // the shelf itself then takes the request when it appears.
        .onChange(of: libraryRequest) { _, request in
            if request != nil { shelf = .books }
        }
        .onChange(of: seriesRequest) { _, request in
            if request != nil { shelf = .series }
        }
        .onAppear {
            if libraryRequest != nil { shelf = .books }
            if seriesRequest != nil { shelf = .series }
        }
    }
}

/// The "Livres | Séries" capsule, in Liquid Glass, centred above the tab bar.
struct LibraryShelfPicker: View {
    @Binding var shelf: LibraryShelf

    var body: some View {
        Picker("Rayon", selection: $shelf) {
            ForEach(LibraryShelf.allCases) { shelf in
                Text(shelf.label).tag(shelf)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
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
    func libraryShelfPicker(_ shelf: Binding<LibraryShelf>?) -> some View {
        if let shelf {
            safeAreaInset(edge: .bottom) { LibraryShelfPicker(shelf: shelf) }
        } else {
            self
        }
    }
}
