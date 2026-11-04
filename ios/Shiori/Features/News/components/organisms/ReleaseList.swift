import SwiftUI

/// The upcoming releases a month at a time: the month, then a line per day
/// with its date on the left and the releases of the day beside it.
struct ReleaseList: View {
    let sections: [ReleaseMonthSection]
    let onOpen: (UpcomingRelease) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(sections) { section in
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 6)
                ForEach(section.days) { day in
                    Divider().padding(.leading, 20)
                    HStack(alignment: .top, spacing: 14) {
                        date(day)
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(day.releases) { release in
                                UpcomingReleaseRow(release: release, onOpen: release.author == nil ? nil : { onOpen(release) })
                                    .padding(.horizontal, -20)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 3)
                }
            }
        }
    }

    private func date(_ day: ReleaseDay) -> some View {
        VStack(spacing: 0) {
            if let symbol = day.symbol {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("Suivi"))
                    .padding(.top, 2)
            } else if let weekday = day.weekday {
                Text(weekday).font(.caption2.weight(.bold)).foregroundStyle(.secondary).textCase(.uppercase)
            }
            if day.symbol == nil {
                Text(day.label)
                .font(day.weekday == nil ? .footnote.weight(.bold) : .title2.weight(.bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
                .lineLimit(2)
            }
        }
        .frame(width: 40)
        .padding(.top, 10)
    }
}

#Preview("Release list") {
    ScrollView {
        ReleaseList(
            sections: ReleaseCalendar(releases: UpcomingRelease.previews, now: .now).sections
        ) { _ in }
    }
    .preferredColorScheme(.dark)
}
