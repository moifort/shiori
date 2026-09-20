import Foundation

/// Owns the Audible import from end to end: the connection, the sign-in in
/// flight, the proposed library and what the reader ticked. Kept on the main
/// actor because every property it exposes is read by a view.
@MainActor
@Observable
final class AudibleImportViewModel {
    private(set) var account: AudibleAccount?
    private(set) var books: [ImportableBook] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    private(set) var isSyncing = false
    private(set) var importedCount = 0
    /// What the pass the reader asked for changed. Nil until they ask, and reset
    /// the next time the library is read so the card never reports an old figure
    /// under a fresh date.
    private(set) var lastSyncOutcome: AudibleSyncOutcome?
    /// Whether Amazon has actually answered with a library. Distinct from an
    /// empty `books`, which is also what a failed read and a first paint look
    /// like.
    private(set) var hasReadLibrary = false
    var errorMessage: String?

    /// The store to sign in on. Only read before the first connection: afterwards
    /// the account carries its own.
    var marketplace: AudibleMarketplace = .suggested

    /// Non-nil while Amazon's page is on screen. Setting it to nil abandons the
    /// attempt; the server's half expires on its own half an hour later.
    var signIn: AudibleLogin?

    /// The ASINs the reader ticked.
    private(set) var selected: Set<String> = []

    var isConnected: Bool { account != nil }

    /// What can still be catalogued — the titles already in the library are shown
    /// but never counted, since importing them would do nothing.
    var importable: [ImportableBook] { books.filter { !$0.alreadyInLibrary } }

    var canImport: Bool { !selected.isEmpty && !isImporting }

    /// How many titles Audible holds, and how many are already on the shelf. Both
    /// nil until the library has actually been read, which is not the same thing
    /// as holding nothing: a card that read "0 livres" while still loading would
    /// send a reader off to check the wrong store.
    var totalCount: Int? { hasReadLibrary ? books.count : nil }
    var catalogedCount: Int? {
        hasReadLibrary ? books.count(where: { $0.alreadyInLibrary }) : nil
    }

    func isSelected(_ book: ImportableBook) -> Bool { selected.contains(book.asin) }

    /// The connection, and the library behind it when there is one. Safe to call
    /// again: it is what every screen of this flow returns to.
    func load() async {
        isLoading = true
        errorMessage = nil
        lastSyncOutcome = nil
        do {
            account = try await ImportAPI.account()
            books = account == nil ? [] : try await ImportAPI.library()
            hasReadLibrary = account != nil
            // Everything not already catalogued starts ticked: a reader who
            // opens this wants their library, and unticking a handful beats
            // ticking three hundred.
            selected = Set(importable.map(\.asin))
        } catch {
            // An expired or revoked device answers here. The connection is shown
            // as gone rather than as broken, because reconnecting is the fix.
            if (error as? APIError)?.domainCode == "AUDIBLE_NOT_CONNECTED" {
                account = nil
                books = []
            }
            hasReadLibrary = false
            errorMessage = reportError(error)
        }
        isLoading = false
    }

    func startSignIn() async {
        errorMessage = nil
        do {
            signIn = try await ImportAPI.startSignIn(on: marketplace)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Called with the code the web view caught. Closes the sheet first: the
    /// exchange is a network call, and leaving Amazon's page up behind a spinner
    /// invites a second tap on a code that is good for one exchange.
    func finishSignIn(code: String) async {
        signIn = nil
        isLoading = true
        errorMessage = nil
        do {
            account = try await ImportAPI.completeSignIn(authorizationCode: code)
        } catch {
            errorMessage = reportError(error)
            isLoading = false
            return
        }
        // Straight into the library, without dropping the loading state first:
        // the screen would otherwise flash an empty list between the two calls.
        await load()
    }

    func cancelSignIn() {
        signIn = nil
    }

    func toggle(_ book: ImportableBook) {
        guard !book.alreadyInLibrary else { return }
        if selected.contains(book.asin) {
            selected.remove(book.asin)
        } else {
            selected.insert(book.asin)
        }
    }

    func selectAll() { selected = Set(importable.map(\.asin)) }

    func deselectAll() { selected = [] }

    /// Catalogues what was ticked. Returns the books created so the library can
    /// refresh itself without a second round trip.
    func importSelected() async -> [Book] {
        guard canImport else { return [] }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }
        do {
            let imported = try await ImportAPI.importBooks(asins: Array(selected))
            importedCount = imported.count
            return imported
        } catch {
            errorMessage = reportError(error)
            return []
        }
    }

    /// Whether the nightly pass runs. Off for a reader with no account: there is
    /// no library to sync, so the switch has nothing to govern.
    var isAutoSyncOn: Bool { account?.autoSync ?? false }

    /// Flips the nightly sync and keeps what the server stored, not what was
    /// asked for. A refused call leaves the switch where it was rather than
    /// showing a setting nothing backs.
    func setAutoSync(_ enabled: Bool) async {
        guard account != nil else { return }
        errorMessage = nil
        do {
            account = try await ImportAPI.setAutoSync(enabled)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Runs the nightly pass now. Reloads the library afterwards rather than
    /// patching it: a pass can catalogue a dozen titles, and every row's
    /// "already there" mark has just changed.
    func syncNow() async {
        guard account != nil, !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let (outcome, synced) = try await ImportAPI.syncNow()
            account = synced
            books = try await ImportAPI.library()
            selected = Set(importable.map(\.asin))
            // Set last: `load()` clears it, and the library read above goes
            // through the same API, not through it.
            lastSyncOutcome = outcome
        } catch {
            errorMessage = reportError(error)
        }
    }

    func disconnect() async {
        errorMessage = nil
        do {
            try await ImportAPI.disconnect()
            account = nil
            books = []
            selected = []
            lastSyncOutcome = nil
            hasReadLibrary = false
        } catch {
            errorMessage = reportError(error)
        }
    }
}
