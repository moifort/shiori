import SwiftUI

/// What an author has for the reader, in a line under their covers, as the
/// section they are in says: among the new releases, the newest book out;
/// among the announcements, the next one and its date. One title only: a few
/// side by side would not fit.
struct AuthorReleasesSummary: View {
    let items: [AuthorNewsItem]
    let section: SagaReleasesSummary.Section

    var body: some View {
        if let line {
            Text(verbatim: line)
                .foregroundStyle(.orange)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
        }
    }

    private var line: String? {
        guard let first = items.first else { return nil }
        switch section {
        case .upcoming:
            guard let date = first.date else { return String(localized: "À venir : \(first.title)") }
            return String(localized: "À venir : \(first.title) · \(ReleaseDateText.short(date))")
        case .recent:
            return String(localized: "Disponible : \(first.title)")
        }
    }
}

#Preview("Author releases summary") {
    let news = AuthorNews(parts: [.init(format: .audiobook, row: .preview)])
    List {
        ForEach([SagaReleasesSummary.Section.upcoming, .recent], id: \.self) { section in
            AuthorReleasesSummary(
                items: AuthorNewsItem.ordered(
                    works: news.works(in: section),
                    awaited: news.awaited(in: section),
                    volumes: news.volumes(in: section),
                    section: section
                ),
                section: section
            )
        }
    }
}
