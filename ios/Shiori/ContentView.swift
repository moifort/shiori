import SwiftUI

enum TabSelection: Int, CaseIterable, Identifiable {
    case home, library, series, scan
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .home: String(localized: "Accueil")
        case .library: String(localized: "Bibliothèque")
        case .series: String(localized: "Séries")
        case .scan: String(localized: "Scanner")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .library: "books.vertical"
        case .series: "square.stack"
        case .scan: "camera.viewfinder"
        }
    }
}

struct ContentView: View {
    @Environment(\.isAdmin) private var isAdmin

    @State private var selectedTab: TabSelection = .home
    /// The last real content tab, restored when the scan cover is dismissed.
    @State private var lastContentTab: TabSelection = .home
    @State private var showScanner = false

    /// The trailing "Scanner" entry must stay detached from the content tabs.
    /// iOS 26 separates the `.search` role; iOS 27 folded `.search` back into the
    /// main tab row and introduced `.prominent` for a trailing-separated tab.
    /// Pick the role that detaches on the running OS, guarding `.prominent`
    /// behind the SDK that defines it so the app still builds with Xcode 26.
    private var scanTabRole: TabRole {
        #if compiler(>=6.4)
        if #available(iOS 27.0, *) {
            return .prominent
        }
        #endif
        return .search
    }

    var body: some View {
        tabs
            .fullScreenCover(isPresented: $showScanner) {
                ScanView(onDismiss: { showScanner = false })
            }
            .onChange(of: selectedTab) { _, tab in
                // The scan tab is a button, not a destination: it opens the
                // camera and hands the selection straight back, so the tab bar
                // never shows a selected "Scanner" with nothing behind it.
                if tab == .scan {
                    showScanner = true
                    selectedTab = lastContentTab
                } else {
                    lastContentTab = tab
                }
            }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(TabSelection.home.label, systemImage: TabSelection.home.symbol, value: .home) {
                HomeView()
            }
            Tab(
                TabSelection.library.label,
                systemImage: TabSelection.library.symbol,
                value: .library
            ) {
                LibraryView()
            }
            Tab(TabSelection.series.label, systemImage: TabSelection.series.symbol, value: .series) {
                SeriesListView()
            }
            Tab(
                TabSelection.scan.label,
                systemImage: TabSelection.scan.symbol,
                value: .scan,
                role: scanTabRole
            ) {
                // Never rendered: the selection is handed back before this
                // appears. The cover owns the camera.
                Color.clear
            }
        }
    }
}
