import Foundation

/// Owns the Kindle connection from end to end: the sign-in in flight, the
/// proposed library and what the reader ticked. Kept on the main actor because
/// every property it exposes is read by a view.
@MainActor
@Observable
final class KindleImportViewModel {
    private(set) var account: KindleAccount?
    private(set) var books: [ImportableKindleBook] = []
    private(set) var isLoading = false
    private(set) var isImporting = false
    private(set) var isSyncing = false
    /// What the pass the reader asked for changed. Nil until they ask.
    private(set) var lastSyncOutcome: SyncOutcome?
    /// Whether Amazon has actually answered with a library — distinct from an
    /// empty `books`, which is also what a failed read looks like.
    private(set) var hasReadLibrary = false
    var errorMessage: String?

    /// The store to sign in on. Only read before the first connection.
    var marketplace: AmazonMarketplace = .suggested

    /// Non-nil while Amazon's page is on screen.
    var signIn: AmazonLogin?

    /// The ASINs the reader ticked.
    private(set) var selected: Set<String> = []

    var importable: [ImportableKindleBook] { books.filter { !$0.alreadyInLibrary } }

    var canImport: Bool { !selected.isEmpty && !isImporting }

    var totalCount: Int? { hasReadLibrary ? books.count : nil }
    var catalogedCount: Int? {
        hasReadLibrary ? books.count(where: { $0.alreadyInLibrary }) : nil
    }

    func isSelected(_ book: ImportableKindleBook) -> Bool { selected.contains(book.asin) }

    /// The connection, and the library behind it when there is one.
    func load() async {
        isLoading = true
        errorMessage = nil
        lastSyncOutcome = nil
        do {
            let connection = try await KindleAPI.connection()
            account = connection?.account
            books = connection?.library ?? []
            hasReadLibrary = connection != nil
            // Everything not already catalogued starts ticked: unticking a
            // handful beats ticking three hundred.
            selected = Set(importable.map(\.asin))
        } catch {
            if (error as? APIError)?.domainCode == "KINDLE_NOT_CONNECTED" {
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
            signIn = try await KindleAPI.startSignIn(on: account?.marketplace ?? marketplace)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Called with the code the web view caught. Closes the sheet first: the
    /// code is good for one exchange, and Amazon's page left up behind a spinner
    /// invites a second tap.
    func finishSignIn(code: String) async {
        signIn = nil
        isLoading = true
        errorMessage = nil
        do {
            account = try await KindleAPI.completeSignIn(authorizationCode: code)
        } catch {
            errorMessage = reportError(error)
            isLoading = false
            return
        }
        await load()
    }

    func cancelSignIn() {
        signIn = nil
    }

    func toggle(_ book: ImportableKindleBook) {
        guard !book.alreadyInLibrary else { return }
        if selected.contains(book.asin) {
            selected.remove(book.asin)
        } else {
            selected.insert(book.asin)
        }
    }

    func selectAll() { selected = Set(importable.map(\.asin)) }

    func deselectAll() { selected = [] }

    /// Catalogues what was ticked, and returns the books created.
    func importSelected() async -> [Book] {
        guard canImport else { return [] }
        isImporting = true
        errorMessage = nil
        defer { isImporting = false }
        do {
            return try await KindleAPI.importBooks(asins: Array(selected))
        } catch {
            errorMessage = reportError(error)
            return []
        }
    }

    /// Flips the nightly sync and keeps what the server stored.
    func setAutoSync(_ enabled: Bool) async {
        guard account != nil else { return }
        errorMessage = nil
        do {
            account = try await KindleAPI.setAutoSync(enabled)
        } catch {
            errorMessage = reportError(error)
        }
    }

    /// Runs the nightly pass now, and redraws from its answer.
    func syncNow() async {
        guard account != nil, !isSyncing else { return }
        isSyncing = true
        errorMessage = nil
        defer { isSyncing = false }
        do {
            let (outcome, synced, library) = try await KindleAPI.syncNow(withLibrary: true)
            account = synced
            books = library ?? []
            hasReadLibrary = true
            selected = Set(importable.map(\.asin))
            lastSyncOutcome = outcome
        } catch {
            errorMessage = reportError(error)
        }
    }

    func disconnect() async {
        errorMessage = nil
        do {
            try await KindleAPI.disconnect()
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
