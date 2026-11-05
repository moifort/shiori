import Foundation
import Testing
@testable import Shiori

/// The detail pages open on their last snapshot: what they keep must come
/// back from disk as it went in, and a page of something deleted must not.
struct SnapshotCacheTests {
    private func roundTrip<Value: Codable>(_ value: Value) throws -> Value {
        try JSONDecoder().decode(Value.self, from: JSONEncoder().encode(value))
    }

    @Test func detailPagesComeBackFromDisk() throws {
        #expect(try roundTrip(AuthorPage.preview).author.id == AuthorPage.preview.author.id)
        #expect(try roundTrip(NarratorPage.preview).key == NarratorPage.preview.key)
        #expect(try roundTrip(Wishlist.preview) == Wishlist.preview)
        let book = try roundTrip(BookViewModel.Snapshot(book: .preview, sagaVolumes: []))
        #expect(book.book == Book.preview)
    }

    @Test func aForgottenSnapshotIsGone() {
        let cache = SnapshotCache<Wishlist>("test-forget-\(UUID().uuidString)", version: 1)
        cache.write(.preview)
        #expect(cache.read() == Wishlist.preview)

        cache.forget()

        #expect(cache.read() == nil)
    }
}
