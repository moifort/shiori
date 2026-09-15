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
    static let genres: [Color] = [.purple, .cyan, .orange, .pink]
    static let others = Color.gray
}
