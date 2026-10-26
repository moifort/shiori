import SwiftUI

/// A volume announced, as "Prochaines sorties" lists it: its cover small, the
/// series and the number, the day it comes out, and on the trailing edge how
/// long until then — "47" over "jours", "4" over "mois".
struct SeriesReleaseRow: View {
    let series: FollowedSeries
    let release: FollowedSeries.Release
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 14) {
                PosterCover(
                    book: Book(
                        id: "release-\(series.id)",
                        title: release.title,
                        authors: [],
                        coverURL: release.coverURL ?? series.cardCoverURL,
                        status: .toRead
                    ),
                    caption: "",
                    width: 46,
                    showsAudioTag: false
                )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(day)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let countdown {
                    VStack(spacing: 0) {
                        Text(countdown.figure)
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Text(countdown.unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        guard let number = release.number else { return "\(series.name) · \(release.title)" }
        return String(localized: "\(series.name) · Tome \(number)")
    }

    /// "Vendredi 12 décembre", "Mars 2027", "2027".
    private var day: String {
        let parts = release.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count > 1,
              let date = Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts.count > 2 ? parts[2] : 1))
        else { return release.date }
        let text = parts.count > 2
            ? date.formatted(.dateTime.weekday(.wide).day().month(.wide))
            : date.formatted(.dateTime.month(.wide).year())
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// The days or months left, split in its figure and its unit.
    private var countdown: (figure: String, unit: String)? {
        guard let text = ReleaseDateText.countdown(release.date) else { return nil }
        let pieces = text.split(maxSplits: 1, whereSeparator: \.isWhitespace).map(String.init)
        guard pieces.count == 2 else { return (text, "") }
        return (pieces[0], pieces[1])
    }
}

#Preview {
    if let saga = SeriesFixtures.followed.first(where: { $0.nextRelease != nil }), let release = saga.nextRelease {
        SeriesReleaseRow(series: saga, release: release) {}
    }
}
