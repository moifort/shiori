import Foundation
import Testing
@testable import Shiori

struct BookFieldTests {
    @Test func aDayNotReachedYetIsNotOfferedForCorrection() {
        // The server refuses a start on a book still on the pile, and a finish
        // on one not read: offering the empty day only led to a refusal.
        let reading = Book.preview

        #expect(BookField.addedAt.isEditable(on: reading))
        #expect(BookField.startedAt.isEditable(on: reading))
        #expect(!BookField.finishedAt.isEditable(on: reading))
        #expect(!BookField.startedAt.isEditable(on: .previewFromShelf))
    }

    @Test func aFactIsCorrectedWhetherKnownOrNot() {
        #expect(BookField.pageCount.isEditable(on: .previewFromShelf))
        #expect(BookField.isbn13.isEditable(on: .previewFromShelf))
    }
}
