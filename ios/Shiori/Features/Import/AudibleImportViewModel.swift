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
    private(set) var importedCount = 0
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

    func isSelected(_ book: ImportableBook) -> Bool { selected.contains(book.asin) }

    /// The connection, and the library behind it when there is one. Safe to call
    /// again: it is what every screen of this flow returns to.
    func load() async {
        isLoading = true
        errorMessage = nil
        do {
            account = try await ImportAPI.account()
            books = account == nil ? [] : try await ImportAPI.library()
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

    func disconnect() async {
        errorMessage = nil
        do {
            try await ImportAPI.disconnect()
            account = nil
            books = []
            selected = []
        } catch {
            errorMessage = reportError(error)
        }
    }
}
