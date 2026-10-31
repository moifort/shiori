import SwiftUI

/// One announced book in the calendar: its cover, its title and why the
/// reader is told of it. An announcement with no title is a "?".
struct UpcomingReleaseRow: View {
    let release: UpcomingRelease
    /// A bar down the left, as the day's list draws it.
    var showsBar = false
    /// Closes the subtitle: the month a release past the six months is announced for.
    var month: String?
    var onOpen: (() -> Void)?

    var body: some View {
        Button { onOpen?() } label: {
            HStack(spacing: 12) {
                if showsBar {
                    Capsule().fill(.white.opacity(0.8)).frame(width: 3)
                }
                thumbnail
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold)).lineLimit(2)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 7)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(onOpen != nil)
    }

    private var title: String {
        if let title = release.title { return title }
        return release.format == .book ? String(localized: "Nouveau roman") : String(localized: "Nouveau livre")
    }

    private var subtitle: String {
        [baseSubtitle, month].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private var baseSubtitle: String {
        guard release.title == nil else {
            return release.date == nil && release.source == .awaited
                ? "\(release.authors.first ?? "") · \(String(localized: "annoncé, jamais daté"))"
                : release.reason
        }
        return "\(release.authors.first ?? "") · \(String(localized: "sans titre"))"
    }

    @ViewBuilder
    private var thumbnail: some View {
        if release.title == nil {
            RoundedRectangle(cornerRadius: 3)
                .fill(LinearGradient(colors: [Color(white: 0.29), Color(white: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 30, height: 45)
                .overlay { Text(verbatim: "?").font(.caption.weight(.semibold)) }
        } else {
            BookCover(book: release.cover, width: 30, showsFormatBadge: false)
        }
    }
}

#Preview("Upcoming release rows") {
    VStack(alignment: .leading) {
        ForEach(UpcomingRelease.previews) { UpcomingReleaseRow(release: $0, showsBar: true) }
    }
    .preferredColorScheme(.dark)
}
