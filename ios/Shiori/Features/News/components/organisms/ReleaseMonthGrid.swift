import SwiftUI

/// A month as a grid, Monday first, with a dot under each day something comes
/// out on (three at most). The day chosen is a white disc.
struct ReleaseMonthGrid: View {
    let month: ReleaseMonth
    let selectedDay: Int
    let onSelect: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private static let weekdays = ["L", "M", "M", "J", "V", "S", "D"]

    var body: some View {
        VStack(spacing: 4) {
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(Self.weekdays.enumerated()), id: \.offset) { _, letter in
                    Text(letter).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(0..<month.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 42) }
                ForEach(1...month.dayCount, id: \.self) { day in
                    cell(day)
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private func cell(_ day: Int) -> some View {
        let count = min(3, month.byDay[day]?.count ?? 0)
        let isSelected = day == selectedDay
        return Button { onSelect(day) } label: {
            VStack(spacing: 2) {
                Text(verbatim: String(day))
                    .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                    .frame(width: 30, height: 30)
                    .foregroundStyle(isSelected ? Color.black : Color.primary)
                    .background(isSelected ? Color.white : Color.clear, in: .circle)
                HStack(spacing: 3) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle().fill(.white.opacity(0.75)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: 42)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(count > 0)
        .accessibilityLabel("\(day) \(month.name)")
        .accessibilityValue(count == 0 ? "" : String(localized: "\(month.byDay[day]?.count ?? 0) sorties"))
    }
}

#Preview("Month grid") {
    let calendar = ReleaseCalendar(releases: UpcomingRelease.previews, now: .now)
    let month = calendar.thisMonth
    ReleaseMonthGrid(month: month, selectedDay: calendar.initialDay(in: month)) { _ in }
        .preferredColorScheme(.dark)
}
