import SwiftUI

/// Stars the reader sets, in half steps: a tap on the leading half of a star
/// gives the half, on its trailing half the whole star, and a finger slid
/// along the row follows it. Each star is a full touch target wide, so a half
/// is still half a thumb.
///
/// The binding changes once, when the finger lifts: the prompt rates on that
/// change, and a slide across the row must not send a rating per star crossed.
struct InteractiveStarRating: View {
    @Binding var rating: Double
    var total: Int = 5
    /// Tapping the current rating clears it. Turned off where the score is
    /// already stored: the API merges the fields it receives and has no way to
    /// express "erase this one", so an unset would silently do nothing.
    var allowsUnset: Bool = true

    /// The rating under the finger, drawn while it is down.
    @State private var pending: Double?
    @Environment(\.layoutDirection) private var layoutDirection

    private static let starWidth: CGFloat = 44

    private var shown: Double { pending ?? rating }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...total, id: \.self) { star in
                let symbol = StarSymbol(star: star, rating: shown)
                Image(systemName: symbol.name)
                    .foregroundStyle(symbol == .empty ? .gray.opacity(0.4) : .yellow)
                    .font(.title)
                    .scaleEffect(Double(star) == shown.rounded(.up) ? 1.15 : 1.0)
                    .animation(.spring(duration: 0.2), value: shown)
                    .frame(width: Self.starWidth, height: Self.starWidth)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { pending = stars(at: $0.location.x) }
                .onEnded { drag in
                    let lifted = stars(at: drag.location.x)
                    let isTap = abs(drag.translation.width) < 4
                    rating = isTap && lifted == rating && allowsUnset ? 0 : lifted
                    pending = nil
                }
        )
        .sensoryFeedback(.selection, trigger: shown)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Note : \(rating.starsText) sur \(total)"))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: rating = min(Double(total), max(1, rating + 0.5))
            case .decrement: rating = rating > 1 ? rating - 0.5 : (allowsUnset ? 0 : 1)
            @unknown default: break
            }
        }
    }

    /// The rating a point of the row stands for: the half star it falls in,
    /// one star at the least.
    private func stars(at x: CGFloat) -> Double {
        let width = Self.starWidth * CGFloat(total)
        let along = layoutDirection == .rightToLeft ? width - x : x
        let halves = (along / (Self.starWidth / 2)).rounded(.up)
        return min(Double(total), max(1, Double(halves) / 2))
    }
}

#Preview {
    @Previewable @State var rating = 3.5
    InteractiveStarRating(rating: $rating)
}
