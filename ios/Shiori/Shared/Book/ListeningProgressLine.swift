import SwiftUI

/// How far a recording got, on a small bar, and what is left to hear, as the
/// TV app says the minutes left of an episode: "11h18 restantes", the units
/// set against their figures, then the share heard: "11h18 restantes · 46%",
/// the sign against its figure. Without a running time, the share alone. Drawn
/// in white: it sits on a cover's colours, on the home's card and a book's
/// hero alike.
struct ListeningProgressLine: View {
    let progress: Int
    /// The recording's length, for the time left. Nil says the share heard.
    var durationMinutes: Int?

    private static let width: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: Self.width, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: Self.width * CGFloat(clamped) / 100, height: 4)
                }
            Text(remaining.map { "\($0) · \(clamped)%" } ?? String(localized: "\(progress)% écouté"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }

    private var clamped: Int { min(max(progress, 0), 100) }

    /// The time left in the recording, when its length is known.
    private var remaining: String? {
        guard let total = durationMinutes else { return nil }
        let left = total * (100 - clamped) / 100
        let hours = left / 60
        let minutes = left % 60
        let label = hours == 0
            ? String(localized: "\(minutes)min")
            : minutes == 0 ? String(localized: "\(hours)h") : String(localized: "\(hours)h\(String(format: "%02d", minutes))")
        return String(localized: "\(label) restantes")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ListeningProgressLine(progress: 30, durationMinutes: 969)
        ListeningProgressLine(progress: 46)
    }
    .padding()
    .background(.black)
}
