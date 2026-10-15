import SwiftUI

/// Where the reader stands in a saga, drawn as an activity ring: the track is
/// the published spine, the arc the part of it read. The count sits inside, so
/// the ring is read at a glance and the figure checked in the same place.
struct SeriesRing: View {
    let read: Int
    let total: Int

    private var fraction: Double { total > 0 ? Double(read) / Double(total) : 0 }
    private var complete: Bool { total > 0 && read == total }
    private var tint: Color { complete ? .green : .pink }

    var body: some View {
        GeometryReader { proxy in
            let lineWidth = proxy.size.width * 0.14
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.2), lineWidth: lineWidth)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.75), tint],
                            center: .center,
                            startAngle: .zero,
                            endAngle: .degrees(360 * max(fraction, 0.01))
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                // One line, no spaces, in the weight of the count: "3/7".
                Text(verbatim: "\(read)/\(total)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, lineWidth)
            }
            .padding(lineWidth / 2)
        }
        .animation(.easeOut(duration: 0.6), value: fraction)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(read) tomes lus sur \(total) parus"))
    }
}

#Preview("Ring") {
    HStack(spacing: 24) {
        SeriesRing(read: 0, total: 7).frame(width: 84, height: 84)
        SeriesRing(read: 3, total: 7).frame(width: 84, height: 84)
        SeriesRing(read: 7, total: 7).frame(width: 84, height: 84)
    }
    .padding()
}
