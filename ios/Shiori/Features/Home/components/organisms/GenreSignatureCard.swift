import SwiftUI

/// The shape of a reader's tastes: the genre they read most, spelled out, and a
/// radar of the few that follow, drawn against the first.
struct GenreSignatureCard: View {
    let readCount: Int
    let shares: [GenreInsights.Share]

    /// A radar needs three axes to enclose anything.
    private var axes: [GenreInsights.Share] { Array(shares.prefix(6)) }

    var body: some View {
        WidgetCard(title: "Votre signature") {
            if let first = shares.first {
                headline(first)
                if axes.count >= 3 {
                    GenreRadar(shares: axes, tint: first.genre.tint)
                        .frame(height: 250)
                }
                HStack(spacing: 6) {
                    Pill(text: String(localized: "\(readCount) lus"))
                    Pill(text: String(localized: "\(shares.count) genres sur \(BookGenre.allCases.count - 1)"))
                }
            }
        }
    }

    private func headline(_ first: GenreInsights.Share) -> some View {
        HStack(alignment: .top, spacing: 12) {
            first.genre.image
                .font(.title2)
                .foregroundStyle(first.genre.tint)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(first.genre.label)
                    .font(.title2.weight(.bold))
                Text("\(percent(first)) % de vos lectures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if shares.count > 1 {
                    Text(runnersUp)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var runnersUp: String {
        let names = shares.dropFirst().prefix(2).map(\.genre.label)
        return String(localized: "Devant \(names.formatted(.list(type: .and)))")
    }

    private func percent(_ share: GenreInsights.Share) -> Int {
        guard readCount > 0 else { return 0 }
        return Int((Double(share.count) / Double(readCount) * 100).rounded())
    }
}

/// One axis per genre, its length the genre's count against the most read.
private struct GenreRadar: View {
    let shares: [GenreInsights.Share]
    let tint: Color

    var body: some View {
        let top = Double(shares.map(\.count).max() ?? 1)
        let values = shares.map { Double($0.count) / top }
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - 40
            ZStack {
                RadarPolygon(values: Array(repeating: 1, count: shares.count), radius: radius)
                    .stroke(.quaternary, lineWidth: 1)
                RadarPolygon(values: Array(repeating: 0.5, count: shares.count), radius: radius)
                    .stroke(.quaternary, lineWidth: 1)
                RadarPolygon(values: values, radius: radius)
                    .fill(tint.opacity(0.22))
                RadarPolygon(values: values, radius: radius)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
                ForEach(Array(shares.enumerated()), id: \.element.id) { index, share in
                    VStack(spacing: 1) {
                        share.genre.image
                            .font(.footnote)
                            .foregroundStyle(share.genre.tint)
                        Text(share.genre.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                    .position(RadarPolygon.point(index, of: shares.count, at: radius + 30, around: center))
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// A closed polygon through one point per axis, the first axis pointing up.
private struct RadarPolygon: Shape {
    let values: [Double]
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for (index, value) in values.enumerated() {
            let point = Self.point(index, of: values.count, at: radius * value, around: center)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    static func point(_ index: Int, of count: Int, at distance: CGFloat, around center: CGPoint) -> CGPoint {
        let angle = -Double.pi / 2 + 2 * Double.pi * Double(index) / Double(count)
        return CGPoint(x: center.x + distance * cos(angle), y: center.y + distance * sin(angle))
    }
}

#Preview {
    GenreSignatureCard(readCount: GenreInsights.preview.readCount, shares: GenreInsights.preview.shares)
        .padding()
        .background(Color(.systemGroupedBackground))
}
