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
    /// An invitation the reader arrived on by tapping a link, owned by
    /// `AuthRoot` so that it survives signing in, and cleared once asked.
    @Binding var invitation: InvitationRequest?

    @Environment(\.isAdmin) private var isAdmin

    @State private var selectedTab: TabSelection = .home
    /// The last real content tab, restored when the scan cover is dismissed.
    @State private var lastContentTab: TabSelection = .home
    @State private var showScanner = false
    /// A shelf the Home tab asked the Library to open on, consumed once applied.
    @State private var libraryFilterRequest: ReadingStatus?
    /// A page shared into Shiori from elsewhere on the phone, picked up when the
    /// app comes to the front. Nil the rest of the time.
    @State private var sharedStart: ScanView.Start?
    @Environment(\.scenePhase) private var scenePhase

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
            // A page shared from Safari or a bookshop app: the extension left it
            // in the container both halves see, and this is where it is picked
            // up. On every return to the front, because the extension cannot
            // bring the app forward itself — the reader shares, then opens
            // Shiori, and the book is waiting for them.
            .fullScreenCover(item: $sharedStart) { start in
                ScanView(start: start, onDismiss: { sharedStart = nil })
            }
            // The invitation is asked about rather than accepted: the link
            // came from somewhere the reader does not control, and accepting
            // opens their library to whoever sent it.
            .sheet(item: $invitation) { request in
                InvitationAcceptSheet(request: request, onAccepted: {})
            }
            .task { takeSharedIntake() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { takeSharedIntake() }
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

    /// Whatever the share extension left, turned into the flow that suits it: a
    /// shared image goes through the scan, a page through its link, a selection
    /// through the title lookup. Nothing to take is the ordinary case.
    private func takeSharedIntake() {
        guard sharedStart == nil, !showScanner, let taken = SharedIntake.take() else { return }
        if let image = taken.image {
            sharedStart = .photo(image)
        } else if let url = taken.intake.url, !url.isEmpty {
            sharedStart = .link(url)
        } else if let text = taken.intake.text?.trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty
        {
            sharedStart = .title(text)
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(TabSelection.home.label, systemImage: TabSelection.home.symbol, value: .home) {
                HomeView(
                    onShowReading: {
                        libraryFilterRequest = .reading
                        selectedTab = .library
                    },
                    onShowSeries: { selectedTab = .series },
                    onScan: { showScanner = true }
                )
            }
            Tab(
                TabSelection.library.label,
                systemImage: TabSelection.library.symbol,
                value: .library
            ) {
                LibraryView(filterRequest: $libraryFilterRequest)
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
