import PhotosUI
import SwiftUI

enum TabSelection: Int, CaseIterable, Identifiable {
    case home, library, news, friends, scan
    var id: Int { rawValue }

    var label: String {
        switch self {
        case .home: String(localized: "Accueil")
        case .library: String(localized: "Bibliothèque")
        case .news: String(localized: "Actu")
        case .friends: String(localized: "Amis")
        case .scan: String(localized: "Scanner")
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        // An open book, as the Books app wears on its icon.
        case .library: "book"
        case .news: "newspaper"
        case .friends: "person.2"
        case .scan: "camera.viewfinder"
        }
    }
}

struct ContentView: View {
    /// An invitation the reader arrived on by tapping a link, owned by
    /// `AuthRoot` so that it survives signing in, and cleared once taken up.
    @Binding var invitation: InvitationRequest?
    /// The friend an invitation just joined, celebrated on the Amis tab.
    @State private var welcomedFriend: String?
    /// Why the invitation could not be taken up: expired, spent, the reader's own.
    @State private var invitationError: String?
    /// Set as onboarding ends: the first opening asks once for a pasted link.
    @AppStorage(PastedInvitation.pendingKey) private var pastedInvitationPending = false
    @State private var offersPastedInvitation = false

    @Environment(\.isAdmin) private var isAdmin

    @State private var selectedTab: TabSelection = .home
    /// The last real content tab, restored when the scan cover is dismissed.
    @State private var lastContentTab: TabSelection = .home
    /// The Library view the dashboard asked for, handed to the Library tab.
    @State private var libraryMode: LibraryRequest?
    /// The same for the Library tab's series shelf.
    @State private var seriesMode: SeriesRequest?
    /// The friend a Découvrir pill asked for, handed to the Amis tab.
    @State private var friendRequest: String?
    /// The add sheet, behind the tab bar's scan button: the camera, the last
    /// photos, a title and a record typed by hand, from every tab.
    @State private var showAddSheet = false
    /// What the add sheet chose, acted on once it has closed: the scanner and
    /// the form are presentations of their own and would fight the sheet on
    /// its way out.
    @State private var pendingSource: AddBookSource?
    @State private var scanStart: ScanStart?
    @State private var shelfStart: ShelfStart?
    /// The offer, for a free reader who chose the shelf import.
    @State private var shelfPaywall = false
    @Environment(SubscriptionStore.self) private var subscriptions
    @State private var showPhotoPicker = false
    @State private var pickedPhoto: PhotosPickerItem?
    @State private var showManualAdd = false
    /// A page shared into Shiori from elsewhere on the phone, picked up when the
    /// app comes to the front. Nil the rest of the time.
    @State private var sharedStart: ScanScreen.Start?
    @Environment(\.scenePhase) private var scenePhase
    /// When the app last left the screen, so that a return after a while asks
    /// every list again. Nil while the app is in front.
    @State private var backgroundedAt: Date?
    /// The Audible player: one for the whole app, so the title plays on
    /// whatever tab is open.
    @State private var player = AudiblePlayer(restoresLastTitle: true)
    @State private var showPlayer = false
    /// The book the player's three dots asked for, pushed on the tab in front
    /// once the player has closed.
    @State private var pendingPlayerBook: String?
    @State private var playerBookRoute = PlayerBookRoute()
    /// Where the pill sits over the tab bar, in the window: the player grows
    /// out of it and goes back into it.
    @State private var playerPillFrame: CGRect = .zero

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
        let start: ScanScreen.Start
    }

    /// The shelf import's opening step, boxed for the same reason.
    private struct ShelfStart: Identifiable {
        let id = UUID()
        let start: ShelfImportScreen.Start
    }

    var body: some View {
        tabs
            .sheet(isPresented: $showAddSheet, onDismiss: actOnPendingSource) {
                AddBookSheet(searchTitle: ScanClient.live.searchTitle, onChoose: choose)
            }
            .fullScreenCover(item: $scanStart) { boxed in
                ScanScreen(
                    start: boxed.start,
                    onDismiss: { scanStart = nil },
                    onAwait: { draft, format in
                        scanStart = nil
                        showAwaited(draft, format)
                    },
                    onAdded: { book in
                        scanStart = nil
                        showAdded(book)
                    },
                    onWished: {
                        scanStart = nil
                        showWishlist()
                    }
                )
            }
            .fullScreenCover(item: $shelfStart) { boxed in
                ShelfImportScreen(start: boxed.start, onDismiss: { shelfStart = nil })
            }
            .sheet(isPresented: $shelfPaywall) {
                PremiumSheet(trigger: .shelfImport)
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
                ManualAddScreen(onAdded: { _ in showManualAdd = false })
            }
            // A page shared from Safari or a bookshop app: the extension left it
            // in the container both halves see, and this is where it is picked
            // up. On every return to the front, because the extension cannot
            // bring the app forward itself — the reader shares, then opens
            // Shiori, and the book is waiting for them.
            .fullScreenCover(item: $sharedStart) { start in
                ScanScreen(
                    start: start,
                    onDismiss: { sharedStart = nil },
                    onAwait: { draft, format in
                        sharedStart = nil
                        showAwaited(draft, format)
                    },
                    onAdded: { book in
                        sharedStart = nil
                        showAdded(book)
                    },
                    onWished: {
                        sharedStart = nil
                        showWishlist()
                    },
                    origin: .share
                )
            }
            // The link does everything: tapped, it is taken up at once, and
            // the Amis tab opens on the friend arriving among the others.
            // Once signed in and past onboarding — `AuthRoot` holds it until
            // this view exists.
            .task(id: invitation) {
                guard let request = invitation else { return }
                invitation = nil
                await accept(request)
            }
            .task(id: pastedInvitationPending) { await offerPastedInvitation() }
            .sheet(isPresented: $offersPastedInvitation) {
                PastedInvitationSheet { action in
                    offersPastedInvitation = false
                    if case let .paste(text) = action { takeUp(pasted: text) }
                }
            }
            .alert(
                "Invitation refusée",
                isPresented: .init(
                    get: { invitationError != nil },
                    set: { if !$0 { invitationError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { invitationError = nil }
            } message: {
                Text(invitationError ?? "")
            }
            .task { takeSharedIntake() }
            // A token APNs rotated reaches the server on the next launch.
            .task { await PushRegistrar.shared.refreshRegistration() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background, backgroundedAt == nil { backgroundedAt = .now }
                if phase == .active {
                    takeSharedIntake()
                    refreshAfterAbsence()
                }
            }
            // A release alert tapped: its book is in the Actu tab.
            .onReceive(NotificationCenter.default.publisher(for: .shioriOpenNews)) { _ in
                selectedTab = .news
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

    /// The first opening after onboarding: a link waiting on the pasteboard
    /// is most likely the invitation the web page copied before the install.
    private func offerPastedInvitation() async {
        #if DEBUG
        if Showcase.isOn, ProcessInfo.processInfo.arguments.contains("-showcase-paste-invitation") {
            offersPastedInvitation = true
            return
        }
        #endif
        guard pastedInvitationPending else { return }
        pastedInvitationPending = false
        guard invitation == nil, await PastedInvitation.pasteboardHoldsALink() else { return }
        offersPastedInvitation = true
    }

    /// What the Paste button handed over, taken up as a tapped link would be.
    private func takeUp(pasted text: String) {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let code = InvitationLink.code(from: url)
        else {
            invitationError = String(localized: "Ce lien n'est pas une invitation Shiori.")
            return
        }
        invitation = InvitationRequest(code: code)
    }

    /// Takes an invitation up and shows the friend it joined. Accepting
    /// changes no library, so the Amis tab is told here to ask again.
    private func accept(_ request: InvitationRequest, client: FriendsClient = .live) async {
        do {
            let friend = try await client.accept(request.code)
            NotificationCenter.default.post(name: .shioriDataDidChange, object: nil)
            selectedTab = .friends
            welcomedFriend = friend.userId
        } catch {
            guard !isCancellation(error) else { return }
            invitationError = reportError(error)
        }
    }

    /// A return to the front: iOS kept the app alive, so no screen loads
    /// again by itself, yet the release watch, a Kindle or Audible sync or a
    /// friend may have written in the meantime — a few minutes reading on the
    /// Kindle are enough to move a progress. The change notice with no object
    /// says anything may have moved, and every screen open reloads where the
    /// reader left it. A glance at the notification centre never sends the
    /// app to the background, so it does not count.
    private func refreshAfterAbsence() {
        defer { backgroundedAt = nil }
        guard backgroundedAt != nil else { return }
        NotificationCenter.default.post(name: .shioriDataDidChange, object: nil)
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
                HomeScreen(
                    onShowSeries: { request in
                        seriesMode = request
                        selectedTab = .library
                    },
                    onShowLibrary: { request in
                        libraryMode = request
                        selectedTab = .library
                    },
                    onScan: { showAddSheet = true }
                )
                .environment(\.hostTab, .home)
            }
            Tab(
                TabSelection.library.label,
                systemImage: TabSelection.library.symbol,
                value: .library
            ) {
                LibraryTab(
                    onAdd: { showAddSheet = true },
                    libraryRequest: $libraryMode,
                    seriesRequest: $seriesMode
                )
                .environment(\.hostTab, .library)
            }
            Tab(TabSelection.news.label, systemImage: TabSelection.news.symbol, value: .news) {
                NewsScreen(onShowFriend: { friendId in
                    friendRequest = friendId
                    selectedTab = .friends
                })
                .environment(\.hostTab, .news)
            }
            // The friends took the search's place; the search waits, hidden,
            // until it finds a new home.
            Tab(TabSelection.friends.label, systemImage: TabSelection.friends.symbol, value: .friends) {
                FriendsScreen(friendRequest: $friendRequest, welcomedFriend: $welcomedFriend)
                    .environment(\.hostTab, .friends)
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
        // The bar folds away while a page scrolls down and comes back on the
        // way up, as in Vinarium.
        .tabBarMinimizeBehavior(.onScrollDown)
        // The title playing floats over the bar, and slides between the active
        // tab and the scan button when the bar folds away, as in Music.
        .modifier(PlayerAccessorySlot(player: player) {
            PlayerAccessoryScreen(onOpen: { showPlayer = true })
                // Under the player while it is open, so the sheet lands on
                // it when it shrinks back.
                .opacity(showPlayer ? 0 : 1)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: {
                    playerPillFrame = $0
                }
        })
        // Not a system sheet: pulled down, the player follows the thumb whole,
        // then goes back into its pill, as in Music.
        .overlay {
            if showPlayer {
                PlayerSheet(pillFrame: playerPillFrame, coverURL: player.title?.coverURL, onClosed: closePlayer) {
                    PlayerScreen(onOpenBook: { pendingPlayerBook = $0 })
                } backdrop: {
                    PlayerBackdrop(coverURL: player.title?.coverURL)
                } pill: {
                    PlayerAccessoryScreen(onOpen: {})
                        .glassEffect(.regular, in: .capsule)
                }
                .environment(player)
            }
        }
        .environment(\.playerBookRoute, playerBookRoute)
        // A book page starts a title from here.
        .environment(player)
    }

    /// The player gone back into its pill: the book its three dots asked for
    /// opens on the tab in front.
    private func closePlayer() {
        showPlayer = false
        if let bookID = pendingPlayerBook {
            playerBookRoute.open(bookID, on: selectedTab)
        }
        pendingPlayerBook = nil
    }

    /// A book awaited from a scan's review: the wishlist, where its edition
    /// shows once the server has looked it up — a web search the reader is
    /// not kept waiting on: the list redraws itself on the change notice.
    private func showAwaited(_ draft: BookDraft, _ format: ReleaseFormat) {
        showWishlist()
        Task {
            do {
                _ = try await AwaitedAPI.awaitScanned(draft, format: format)
            } catch {
                _ = reportError(error)
            }
        }
    }

    /// The Library's wishlist, opened over its shelves.
    private func showWishlist() {
        libraryMode = LibraryRequest(opensWishlist: true)
        Task { @MainActor in selectedTab = .library }
    }

    /// A book added from a scan: the Library's books, scrolled to where its
    /// date shelves it.
    private func showAdded(_ book: Book) {
        libraryMode = LibraryRequest(focus: book.id)
        // The tab comes forward once the list has taken the request, so it
        // opens on the list by date rather than flashing the mosaic it was
        // left on.
        Task { @MainActor in selectedTab = .library }
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
        // Unknown until the store has loaded: the flow opens, and the server's
        // PREMIUM_REQUIRED brings the offer up for a free reader all the same.
        case .shelf:
            if subscriptions.isPremium == false {
                shelfPaywall = true
            } else {
                shelfStart = ShelfStart(start: .camera)
            }
        case let .photo(data): scanStart = ScanStart(start: .photo(data))
        case .library: showPhotoPicker = true
        case let .title(title): scanStart = ScanStart(start: .title(title))
        case .manual: showManualAdd = true
        }
    }
}
