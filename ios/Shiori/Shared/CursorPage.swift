import Foundation

/// One page of a list the server cuts by cursor: its rows, whether more
/// follow, and the cursor to ask the next page after. The cursor is the
/// server's to make; the app only hands it back.
struct CursorPage<Item: Sendable>: Sendable {
    let items: [Item]
    let hasMore: Bool
    /// Nil on an empty page.
    let endCursor: String?
}

extension CursorPage {
    /// A page cut from rows already in memory, as the server cuts its own:
    /// after the row the cursor names, from the top when it names none. For
    /// the showcase, the previews and the tests.
    init(_ rows: [Item], limit: Int, after: String?, cursor: (Item) -> String) {
        let start = after.flatMap { after in rows.firstIndex { cursor($0) == after }.map { $0 + 1 } } ?? 0
        let page = Array(rows.dropFirst(start).prefix(limit))
        self.init(
            items: page,
            hasMore: start + page.count < rows.count,
            endCursor: page.last.map(cursor)
        )
    }
}
