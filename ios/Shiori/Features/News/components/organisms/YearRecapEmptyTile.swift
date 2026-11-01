import SwiftUI

/// A year's tile with nothing in it yet: a ground of deep blurred colours,
/// the tile's icon grown large in a corner, a zero, and what is missing.
struct YearRecapEmptyTile: View {
    let kind: YearRecap.Kind

    var body: some View {
        ZStack(alignment: .topLeading) {
            ground
            Image(systemName: kind.systemImage)
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .rotationEffect(.degrees(-12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 6, y: -2)
            VStack(alignment: .leading, spacing: 0) {
                Text(verbatim: "0")
                    .font(.system(size: 30, weight: .heavy))
                Spacer(minLength: 0)
                Text(kind.emptyTitle)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 3, y: 1)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(height: YearRecapTile.height)
        .clipShape(.rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(.white.opacity(0.35)) }
        .accessibilityElement(children: .combine)
    }

    /// A diagonal from one deep colour to another, two lighter spots blurred
    /// into it, and a faint glow in the top corner.
    private var ground: some View {
        let colors = kind.palette
        return LinearGradient(colors: [colors.from, colors.to], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .bottomLeading) {
                Circle().fill(colors.spotLow).frame(width: 110, height: 110).offset(x: -24, y: 34).blur(radius: 20)
            }
            .overlay(alignment: .topTrailing) {
                Circle().fill(colors.spotHigh).frame(width: 90, height: 90).offset(x: -34, y: -44).blur(radius: 20).opacity(0.75)
            }
            .overlay {
                RadialGradient(
                    colors: [.white.opacity(0.16), .clear], center: .init(x: 0.18, y: 0), startRadius: 0, endRadius: 90
                )
            }
            .clipped()
    }
}

#Preview("Empty") {
    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
        ForEach(YearRecap.Kind.allCases, id: \.self) { YearRecapEmptyTile(kind: $0) }
    }
    .padding(20)
    .background(.black)
    .preferredColorScheme(.dark)
}
