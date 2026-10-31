import SwiftUI

/// "Prochainement": the horizon pills and the calendar under them — a month
/// grid with its day's list, the six months side by side, or what lies past
/// them. Draws what it is given.
struct ReleaseCalendarSection: View {
    let calendar: ReleaseCalendar
    @Binding var horizon: ReleaseHorizon
    @Binding var selectedDay: Int?
    let onOpenAll: () -> Void
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onOpenAll) {
                HStack(spacing: 5) {
                    Text("Prochainement").font(.title2.weight(.bold))
                    Image(systemName: "chevron.right").font(.body.weight(.semibold)).foregroundStyle(.secondary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .accessibilityIdentifier("news-upcoming-header")
            FilterPills(
                pills: [
                    .init(id: ReleaseHorizon.month.id, label: calendar.thisMonth.name),
                    .init(id: ReleaseHorizon.sixMonths.id, label: String(localized: "6 mois")),
                    .init(id: ReleaseHorizon.later.id, label: String(localized: "Plus tard")),
                ],
                selected: horizon.id,
                allLabel: nil
            ) { id in
                horizon = ReleaseHorizon(rawValue: id ?? "") ?? .month
            }
            switch horizon {
            case .month: monthContent
            case .sixMonths: ReleaseMonthsOverview(months: calendar.sixMonths)
            case .later: ReleaseLaterList(years: calendar.later, undated: calendar.undated, onOpen: onOpen)
            }
        }
    }

    @ViewBuilder
    private var monthContent: some View {
        let month = calendar.thisMonth
        let day = selectedDay ?? calendar.initialDay(in: month)
        ReleaseMonthGrid(month: month, selectedDay: day) { selectedDay = $0 }
        ReleaseDayList(
            title: calendar.dayTitle(day, in: month),
            releases: month.byDay[day] ?? [],
            monthOnly: month.monthOnly,
            monthName: month.name,
            onOpen: onOpen
        )
    }
}

#Preview("Calendar section") {
    @Previewable @State var horizon = ReleaseHorizon.month
    @Previewable @State var day: Int?
    ScrollView {
        ReleaseCalendarSection(
            calendar: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now),
            horizon: $horizon,
            selectedDay: $day,
            onOpenAll: {},
            onOpen: { _ in }
        )
    }
    .preferredColorScheme(.dark)
}
