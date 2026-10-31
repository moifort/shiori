import SwiftUI

/// The six coming months side by side: each a miniature grid with its release
/// days in white, its count, and a strip of its covers.
struct ReleaseMonthsOverview: View {
    let months: [ReleaseMonth]

    private let columns = [GridItem(.flexible(), spacing: 16, alignment: .top), GridItem(.flexible(), spacing: 16, alignment: .top)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(months) { month in
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(month.name).font(.subheadline.weight(.bold))
                        Spacer()
                        Text(count(month)).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                    }
                    miniGrid(month).padding(.top, 6)
                    HStack(spacing: 4) {
                        ForEach(month.all.prefix(5)) { release in
                            BookCover(book: release.cover, width: 24, showsFormatBadge: false)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private func count(_ month: ReleaseMonth) -> String {
        switch month.all.count {
        case 0: String(localized: "Rien")
        case 1: String(localized: "1 sortie")
        case let many: String(localized: "\(many) sorties")
        }
    }

    private func miniGrid(_ month: ReleaseMonth) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(0..<month.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 15) }
            ForEach(1...month.dayCount, id: \.self) { day in
                let isRelease = month.byDay[day] != nil
                Text(verbatim: String(day))
                    .font(.system(size: 9.5, weight: .semibold))
                    .frame(width: 15, height: 15)
                    .foregroundStyle(isRelease ? Color.black : Color.white.opacity(0.55))
                    .background(isRelease ? Color.white : Color.clear, in: .circle)
            }
        }
    }
}

#Preview("Months overview") {
    ReleaseMonthsOverview(months: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now).sixMonths)
        .preferredColorScheme(.dark)
}
