import SwiftUI

struct StarRatingView: View {
    let rating: Int
    var total: Int = 5
    var font: Font = .caption2

    var body: some View {
        HStack(spacing: 1) {
            ForEach(1...total, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .foregroundStyle(star <= rating ? .yellow : .gray.opacity(0.3))
                    .font(font)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Note : \(rating) sur \(total)"))
    }
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
