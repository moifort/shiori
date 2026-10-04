import Foundation

/// How the admin screen writes its figures: euros with cents, counts grouped,
/// days in UTC since the bill and the sessions are counted in UTC.
enum AdminFormat {
    static func euro(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").precision(.fractionLength(2)))
    }

    static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    static var dayMonth: Date.FormatStyle {
        var style = Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!).day().month(.abbreviated)
        style.calendar = AdminMetrics.utc
        return style
    }

    static var shortMonth: Date.FormatStyle {
        Date.FormatStyle(timeZone: TimeZone(identifier: "UTC")!).month(.abbreviated)
    }
}
