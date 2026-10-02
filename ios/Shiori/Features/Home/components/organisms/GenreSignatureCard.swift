import SwiftUI

/// The genre the reader reads most, spelled out with its share, and the two
/// that follow.
struct GenreSignatureCard: View {
    let readCount: Int
    let shares: [GenreInsights.Share]

    var body: some View {
        WidgetCard(title: "Votre signature") {
            if let first = shares.first {
                headline(first)
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
                Text("\(percent(first))% de vos lectures")
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

/// The shape of a reader's tastes, drawn straight on the page: one axis per
/// genre among the six most read, its length the genre's count against the
/// first. Glassy rather than plotted — a tinted pane over faint rings, the
/// genres named in glass capsules — because it is read as a shape, not
/// measured. A radar needs three axes to enclose anything; fewer draw nothing.
struct GenreRadar: View {
    let shares: [GenreInsights.Share]

    private var axes: [GenreInsights.Share] { Array(shares.prefix(6)) }

    var body: some View {
        if axes.count >= 3, let first = axes.first {
            chart(tint: first.genre.tint)
                .frame(height: 320)
                .accessibilityElement(children: .combine)
        }
    }

    private func chart(tint: Color) -> some View {
        let top = Double(axes.map(\.count).max() ?? 1)
        let values = axes.map { Double($0.count) / top }
        return GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let radius = min(proxy.size.width, proxy.size.height) / 2 - 48
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [tint.opacity(0.14), tint.opacity(0.02)],
                        center: .center,
                        startRadius: 0,
                        endRadius: radius
                    ))
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                ForEach([1.0, 2.0 / 3, 1.0 / 3], id: \.self) { ring in
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        .frame(width: radius * 2 * ring, height: radius * 2 * ring)
                        .position(center)
                }
                RadarSpokes(count: axes.count, radius: radius)
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                RadarPolygon(values: values, radius: radius)
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.55), tint.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .shadow(color: tint.opacity(0.35), radius: 14)
                RadarPolygon(values: values, radius: radius)
                    .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    Circle()
                        .fill(.white)
                        .overlay(Circle().stroke(tint, lineWidth: 2))
                        .frame(width: 9, height: 9)
                        .position(RadarPolygon.point(index, of: values.count, at: radius * value, around: center))
                }
                ForEach(Array(axes.enumerated()), id: \.element.id) { index, share in
                    Label {
                        Text(share.genre.label)
                    } icon: {
                        share.genre.image.foregroundStyle(share.genre.tint)
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
                    .fixedSize()
                    .position(RadarPolygon.point(index, of: axes.count, at: radius + 26, around: center))
                }
            }
        }
    }
}

/// One line from the centre out to each axis.
private struct RadarSpokes: Shape {
    let count: Int
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for index in 0..<count {
            path.move(to: center)
            path.addLine(to: RadarPolygon.point(index, of: count, at: radius, around: center))
        }
        return path
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
    VStack(spacing: 16) {
        GenreRadar(shares: GenreInsights.preview.shares)
        GenreSignatureCard(readCount: GenreInsights.preview.readCount, shares: GenreInsights.preview.shares)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
