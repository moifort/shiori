import Foundation

/// A friend's paged shelf — their books or their sagas — with the "+" that
/// takes a row onto the reader's own. One model for both lists, which only
/// differ in what a row is and how a page is asked for.
///
/// The view and filter the rows were asked under is kept: until the answer
/// for a new one arrives, the rows of the last would be cut the new way —
/// hearts and stars over books listed by date — so the page shows a spinner
/// in their place.
@MainActor
@Observable
final class FriendShelfListModel<Row: Identifiable & Sendable> where Row.ID == String {
    /// One page of rows after the given row id, the first page without one.
    typealias Fetch = @Sendable (_ after: String?) async throws -> (rows: [Row], hasMore: Bool)

    private(set) var rows: [Row] = []
    private(set) var hasMore = false
    /// The query the rows on screen answer; nil before the first answer.
    private(set) var loadedQuery: String?
    private(set) var errorMessage: String?
    private(set) var loadMoreFailed = false
    /// The rows being taken onto the reader's shelf, their "+" turning.
    private(set) var adding: Set<String> = []
    /// A take that failed, said in an alert.
    var addFailed: String?

    private let ownedFlag: WritableKeyPath<Row, Bool>

    /// - Parameter ownedFlag: where a row says the reader holds it already.
    init(ownedFlag: WritableKeyPath<Row, Bool>) {
        self.ownedFlag = ownedFlag
    }

    /// The first page of a new query. A cancellation — the reader switched
    /// view again — says nothing: the next request answers.
    func load(query: String, fetch: Fetch) async {
        errorMessage = nil
        loadMoreFailed = false
        do {
            let page = try await fetch(nil)
            rows = page.rows
            hasMore = page.hasMore
            loadedQuery = query
        } catch {
            guard !isCancellation(error) else { return }
            errorMessage = reportError(error)
        }
    }

    /// The next page, appended; a row the server sends twice is kept once.
    func loadMore(fetch: Fetch) async {
        loadMoreFailed = false
        do {
            let page = try await fetch(rows.last?.id)
            rows.append(contentsOf: page.rows.filter { new in !rows.contains { $0.id == new.id } })
            hasMore = page.hasMore
        } catch {
            _ = reportError(error)
            loadMoreFailed = true
        }
    }

    /// Takes a row onto the reader's shelf; the row then says it is theirs.
    func take(_ rowId: String, add: () async throws -> Void) async {
        adding.insert(rowId)
        defer { adding.remove(rowId) }
        do {
            try await add()
            markOwned(rowId)
        } catch {
            addFailed = reportError(error)
        }
    }

    func markOwned(_ rowId: String) {
        for index in rows.indices where rows[index].id == rowId {
            rows[index][keyPath: ownedFlag] = true
        }
    }
}
