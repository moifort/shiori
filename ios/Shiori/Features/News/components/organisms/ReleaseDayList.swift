import SwiftUI

/// The releases of the day chosen on the grid, under its date; then the ones
/// announced for the month with no day.
struct ReleaseDayList: View {
    let title: String
    let releases: [UpcomingRelease]
    let monthOnly: [UpcomingRelease]
    let monthName: String
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !releases.isEmpty {
                header(title)
                ForEach(releases) { row($0, bar: true) }
            }
            if !monthOnly.isEmpty {
                header(String(localized: "En \(monthName.lowercased()), sans jour précis"))
                ForEach(monthOnly) { row($0, bar: false) }
            }
            if releases.isEmpty, monthOnly.isEmpty {
                Text("Rien d'annoncé ce mois-ci")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
            }
        }
    }

    private func header(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func row(_ release: UpcomingRelease, bar: Bool) -> some View {
        UpcomingReleaseRow(release: release, showsBar: bar, onOpen: release.author == nil ? nil : { onOpen(release) })
    }
}

#Preview("Day list") {
    let calendar = ReleaseCalendar(releases: UpcomingRelease.previews, now: .now)
    let month = calendar.thisMonth
    let day = calendar.initialDay(in: month)
    ReleaseDayList(
        title: calendar.dayTitle(day, in: month),
        releases: month.byDay[day] ?? [],
        monthOnly: month.monthOnly,
        monthName: month.name,
        onOpen: { _ in }
    )
    .preferredColorScheme(.dark)
}
