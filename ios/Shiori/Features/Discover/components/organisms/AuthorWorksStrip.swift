import SwiftUI

/// An author's works announced or just out, and the editions of theirs the
/// reader awaits, as a strip of covers under their row on Découvrir's Authors
/// shelf: each with a clock and its day if it is still to come, a plus if it
/// is out — as the Series tab's strip marks the volumes the reader lacks. The
/// reader's own books are not repeated here. A tap on a cover opens it.
struct AuthorWorksStrip: View {
    let items: [AuthorNewsItem]
    let author: String
    let onTapped: (AuthorNewsItem) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 10) {
                ForEach(items) { work in
                    let coming = work.isComing
                    Button { onTapped(work) } label: { cover(work, coming: coming) }
                        .buttonStyle(.plain)
                }
            }
            // Room for the badges, which overhang the covers' corners, and for
            // the dates under them.
            .padding(.top, 6)
            .padding(.trailing, 6)
            .padding(.bottom, dateLine)
        }
        .scrollIndicators(.hidden)
        .accessibilityHidden(true)
    }

    private func cover(_ work: AuthorNewsItem, coming: Bool) -> some View {
        BookCover(
            book: Book(
                id: "release-\(work.id)",
                title: work.title,
                authors: [author],
                format: work.isAudio ? .audiobook : .book,
                coverURL: work.coverURL,
                status: .toRead
            ),
            width: coverWidth,
            showsFormatBadge: false
        )
        .overlay(alignment: .topTrailing) {
            CoverBadge(systemImage: coming ? "clock" : "plus", tint: coming ? .orange : .accentColor)
                .offset(x: 5, y: -5)
        }
        // Hung under the cover rather than stacked with it, as the
        // Series tab hangs its dates: a lazy stack sizes itself on
        // the covers it drew first. From the cover's leading edge:
        // "nov. 2026" is wider than a cover, and centred the first
        // one would be cut by the scroll view.
        .overlay(alignment: .bottomLeading) {
            if let date = work.date {
                Text(verbatim: ReleaseDateText.short(date))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(coming ? Color.orange : .secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .offset(y: dateLine)
            }
        }
    }

    private let coverWidth: CGFloat = 44
    private let dateLine: CGFloat = 16
}

#Preview {
    let author = AuthorDiscovery.preview
    AuthorWorksStrip(
        items: AuthorNewsItem.ordered(
            works: author.next.map { [($0, .audiobook)] } ?? [],
            awaited: author.awaited,
            volumes: author.sagaComing,
            section: .upcoming
        ),
        author: author.author.name,
        onTapped: { _ in }
    )
    .padding()
}
