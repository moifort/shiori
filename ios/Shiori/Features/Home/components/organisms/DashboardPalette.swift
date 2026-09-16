import SwiftUI

/// The Fitness-like colours of the dashboard. System colours, so they keep their
/// contrast in light and dark appearance alike; each one means one thing.
enum DashboardPalette {
    static let books = Color.pink
    static let pages = Color.green
    static let duration = Color.cyan
    static let pile = Color.orange
    static let rating = Color.yellow
    static let series = Color.purple
    // No purple here: that hue belongs to the series widget just below.
    static let genres: [Color] = [.blue, .orange, .teal, .brown]
    static let others = Color.gray
}
