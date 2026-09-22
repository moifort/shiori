import PhotosUI
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
    /// The Library view the dashboard asked for, handed to the Library tab.
    @State private var libraryMode: LibraryRequest?
    /// The same for the Series tab.
    @State private var seriesMode: SeriesRequest?
    /// The add sheet, behind the tab bar's scan button: the camera, the last
    /// photos, a title and a record typed by hand, from every tab.
    @State private var showAddSheet = false
    /// What the add sheet chose, acted on once it has closed: the scanner and
    /// the form are presentations of their own and would fight the sheet on
    /// its way out.
    @State private var pendingSource: AddBookSource?
    @State private var scanStart: ScanStart?
    @State private var showPhotoPicker = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showManualAdd = false
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

    /// The scanner's opening step, boxed so a cover can be keyed on it.
    private struct ScanStart: Identifiable {
        let id = UUID()
        let start: ScanView.Start
    }

    var body: some View {
        tabs
            .sheet(isPresented: $showAddSheet, onDismiss: actOnPendingSource) {
                AddBookSheet(
                    onCamera: { choose(.camera) },
                    onAllPhotos: { choose(.library) },
                    onPickedPhoto: { choose(.photo($0)) },
                    onTitle: { choose(.title($0)) },
                    onManual: { choose(.manual) }
                )
            }
            .fullScreenCover(item: $scanStart) { boxed in
                ScanView(start: boxed.start, onDismiss: { scanStart = nil })
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: $pickedPhoto, matching: .images)
            .onChange(of: pickedPhoto) { _, item in
                guard let item else { return }
                pickedPhoto = nil
                Task {
                    guard let data = try? await item.loadTransferable(type: Data.self) else { return }
                    scanStart = ScanStart(start: .photo(data))
                }
            }
            // Every list redraws itself on the data-change notice the mutation
            // posts, so the form only has to close.
            .sheet(isPresented: $showManualAdd) {
                ManualAddView(onAdded: { _ in showManualAdd = false })
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
                // The scan tab is a button, not a destination: it opens the add
                // sheet — the camera, and the photos the camera alone would not
                // reach — and hands the selection straight back, so the tab bar
                // never shows a selected "Scanner" with nothing behind it.
                if tab == .scan {
                    showAddSheet = true
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
        guard sharedStart == nil, scanStart == nil, let taken = SharedIntake.take() else { return }
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
                    onShowSeries: { request in
                        seriesMode = request
                        selectedTab = .series
                    },
                    onShowLibrary: { request in
                        libraryMode = request
                        selectedTab = .library
                    },
                    onScan: { showAddSheet = true }
                )
            }
            Tab(
                TabSelection.library.label,
                systemImage: TabSelection.library.symbol,
                value: .library
            ) {
                LibraryView(onAdd: { showAddSheet = true }, requestedMode: $libraryMode)
            }
            Tab(TabSelection.series.label, systemImage: TabSelection.series.symbol, value: .series) {
                SeriesListView(onScan: { showAddSheet = true }, requested: $seriesMode)
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

    private func choose(_ source: AddBookSource) {
        pendingSource = source
        showAddSheet = false
    }

    /// The sheet is gone: open what it chose.
    private func actOnPendingSource() {
        guard let source = pendingSource else { return }
        pendingSource = nil
        switch source {
        case .camera: scanStart = ScanStart(start: .camera)
        case let .photo(data): scanStart = ScanStart(start: .photo(data))
        case .library: showPhotoPicker = true
        case let .title(title): scanStart = ScanStart(start: .title(title))
        case .manual: showManualAdd = true
        }
    }
}
