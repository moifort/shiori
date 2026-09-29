import SwiftUI

/// Where the book stands on a shelf, on top of every page of a book on one —
/// the reader's own, a friend's, a scan about to join it: the segmented
/// status, straight on the sheet rather than in a card. Without a way to
/// change it, it only says where the book stands.
struct BookStatusSection: View {
    let status: ReadingStatus
    var onSetStatus: ((ReadingStatus) -> Void)?

    var body: some View {
        Section {
            ReadingStatusPicker(status: Binding(get: { status }, set: { onSetStatus?($0) }))
                .allowsHitTesting(onSetStatus != nil)
                .accessibilityIdentifier("book-status")
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
        }
    }
}

/// How a book was read, drawn the same whoever read it — "Ma lecture" on the
/// reader's own page, their friend's on a friend's: the rating, then the day it
/// was added, started and finished. Only what is known is drawn. Where the page
/// lets the reader correct it, a tap on the rating or a date opens its prompt.
/// A page adds rows of its own under the dates.
struct BookReadingSection<Extra: View>: View {
    let title: LocalizedStringKey
    let book: Book
    var onRate: (() -> Void)?
    var onEditField: ((BookField) -> Void)?
    var footer: LocalizedStringKey?
    @ViewBuilder var extra: Extra

    var body: some View {
        Section {
            rating
            if let added = book.addedAt {
                dateRow(.addedAt, date: added, icon: "tray.and.arrow.down")
            }
            if let started = book.startedAt {
                dateRow(.startedAt, date: started, icon: "calendar.badge.plus")
            }
            if let finished = book.finishedAt {
                dateRow(.finishedAt, date: finished, icon: "calendar.badge.checkmark")
            }
            extra
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }

    @ViewBuilder
    private var rating: some View {
        if let rating = book.rating {
            ratingRow(accessibility: "book-rating") {
                LabeledContent("Note") { StarRatingView(rating: rating) }
            }
        } else if let seriesRating = book.seriesRating {
            // The saga's stars, lent to this volume: grey, named as such, and
            // a tap gives the book a rating of its own.
            ratingRow(accessibility: "book-rating-inherited") {
                LabeledContent {
                    OpinionMark(rating: seriesRating, isFavorite: false, font: .caption2, ratingIsInherited: true)
                } label: {
                    Text("Note")
                    Text("Héritée de la série")
                }
            }
        } else if let onRate {
            Button(action: onRate) {
                Label("Noter ce livre", systemImage: "star")
            }
            .accessibilityIdentifier("book-rate")
        }
    }

    @ViewBuilder
    private func ratingRow(accessibility: String, @ViewBuilder content: () -> some View) -> some View {
        let label = Label {
            content()
        } icon: {
            Image(systemName: "star").foregroundStyle(.secondary)
        }
        if let onRate {
            Button(action: onRate) { label }
                .tint(.primary)
                .accessibilityIdentifier(accessibility)
        } else {
            label.accessibilityIdentifier(accessibility)
        }
    }

    @ViewBuilder
    private func dateRow(_ field: BookField, date: Date, icon: String) -> some View {
        let value = date.formatted(date: .abbreviated, time: .omitted)
        let label = Label {
            LabeledContent(field.title) { Text(value) }
        } icon: {
            Image(systemName: icon).foregroundStyle(.secondary)
        }
        if let onEditField {
            Button { onEditField(field) } label: { label }
                .tint(.primary)
                .copyable(value)
                .accessibilityIdentifier("book-\(field.rawValue)")
        } else {
            label
                .copyable(value)
                .accessibilityIdentifier("book-\(field.rawValue)")
        }
    }
}

extension BookReadingSection where Extra == EmptyView {
    init(title: LocalizedStringKey, book: Book, footer: LocalizedStringKey? = nil) {
        self.init(title: title, book: book, footer: footer) { EmptyView() }
    }
}
