import SwiftUI

/// Stars as a row draws them. Inherited ones — a saga's rating lent to a
/// volume the reader left unrated — are grey rather than yellow, so a
/// judgement given is told from one lent at a glance.
struct StarRatingView: View {
    let rating: Int
    var total: Int = 5
    var font: Font = .caption2
    var inherited: Bool = false

    private var filled: Color { inherited ? .secondary : .yellow }

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...total, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? filled : .gray.opacity(0.3))
                    .font(font)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            inherited
                ? Text("Note de la série : \(rating) sur \(total)")
                : Text("Note : \(rating) sur \(total)")
        )
    }
}

#Preview("Inherited") {
    StarRatingView(rating: 4, inherited: true)
}

#Preview("None") {
    StarRatingView(rating: 0)
}

#Preview("3 of 5") {
    StarRatingView(rating: 3)
}

#Preview("5 of 5") {
    StarRatingView(rating: 5)
}
