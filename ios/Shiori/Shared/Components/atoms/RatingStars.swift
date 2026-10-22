import SwiftUI

/// Stars as a row draws them, half stars included. Inherited ones — a saga's
/// rating lent to a volume the reader left unrated — are grey rather than
/// yellow, so a judgement given is told from one lent at a glance.
struct RatingStars: View {
    let rating: Double
    var total: Int = 5
    var font: Font = .caption2
    var inherited: Bool = false

    private var filled: Color { inherited ? .secondary : .yellow }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...total, id: \.self) { star in
                let symbol = StarSymbol(star: star, rating: rating)
                Image(systemName: symbol.name)
                    .foregroundStyle(symbol == .empty ? .gray.opacity(0.3) : filled)
                    .font(font)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            inherited
                ? Text("Note de la série : \(rating.starsText) sur \(total)")
                : Text("Note : \(rating.starsText) sur \(total)")
        )
    }
}

/// How one star of a row is drawn for a rating: full, half, or empty.
enum StarSymbol: Equatable {
    case full, half, empty

    init(star: Int, rating: Double) {
        if Double(star) <= rating {
            self = .full
        } else if Double(star) - 0.5 <= rating {
            self = .half
        } else {
            self = .empty
        }
    }

    var name: String {
        switch self {
        case .full: "star.fill"
        case .half: "star.leadinghalf.filled"
        case .empty: "star"
        }
    }
}

extension Double {
    /// A rating as a reader reads it: "4", "3,5" — no trailing zero.
    var starsText: String {
        formatted(.number.precision(.fractionLength(0...1)))
    }
}

#Preview("Inherited") {
    RatingStars(rating: 4, inherited: true)
}

#Preview("None") {
    RatingStars(rating: 0)
}

#Preview("3 of 5") {
    RatingStars(rating: 3)
}

#Preview("3.5 of 5") {
    RatingStars(rating: 3.5)
}

#Preview("5 of 5") {
    RatingStars(rating: 5)
}
