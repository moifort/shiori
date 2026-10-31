import SwiftUI

/// What is announced past the six months, a year at a time, then what is
/// announced with no date at all.
struct ReleaseLaterList: View {
    let years: [ReleaseYear]
    let undated: [UpcomingRelease]
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(years) { year in
                block(label: Text(verbatim: String(year.year)), font: .headline, releases: year.rows.map(\.release), months: year.rows.map(\.month))
            }
            if !undated.isEmpty {
                block(label: Text("Sans date"), font: .footnote.weight(.bold), releases: undated, months: undated.map { _ in nil })
            }
            if years.isEmpty, undated.isEmpty {
                Text("Rien d'annoncé plus loin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func block(label: Text, font: Font, releases: [UpcomingRelease], months: [String?]) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.leading, 20)
            HStack(alignment: .top, spacing: 14) {
                label.font(font.weight(.bold)).frame(width: 52).multilineTextAlignment(.center).minimumScaleFactor(0.8).lineLimit(2)
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(releases.enumerated()), id: \.element.id) { index, release in
                        UpcomingReleaseRow(release: release, month: months[index], onOpen: release.author == nil ? nil : { onOpen(release) })
                            .padding(.horizontal, -20)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
        }
    }
}

#Preview("Later list") {
    let calendar = ReleaseCalendar(releases: UpcomingRelease.previews, now: .now)
    ReleaseLaterList(years: calendar.later, undated: calendar.undated) { _ in }
        .preferredColorScheme(.dark)
}
