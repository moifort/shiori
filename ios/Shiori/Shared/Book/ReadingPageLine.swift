import SwiftUI

/// Where the reader is in a printed or digital book, as the hero draws a
/// recording's progress: a small white bar, then "page 214 · 32%". When the
/// page moves on, the pages just read rise off the line — "+34 pages" — and
/// the bar grows to its new length behind them.
struct ReadingPageLine: View {
    let page: Int
    /// The book's length, for the bar and the share. Nil says the page alone.
    var pageCount: Int?

    /// The pages just read, risen off the line while they show.
    @State private var gain: Int?
    /// Where the pages just read are in their rise: low and hidden, shown,
    /// then gone above.
    @State private var gainPhase = GainPhase.low

    private static let width: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            if let progress {
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(width: Self.width, height: 4)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: Self.width * CGFloat(progress) / 100, height: 4)
                    }
            }
            Text(progress.map { String(localized: "page \(page) · \($0)%") } ?? String(localized: "page \(page)"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
        }
        .overlay(alignment: .topLeading) {
            if let gain {
                Text("+\(gain) pages")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.7), radius: 6)
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    .fixedSize()
                    .scaleEffect(gainPhase == .low ? 0.6 : 1, anchor: .leading)
                    .offset(x: progress == nil ? 0 : Self.width + 8, y: gainPhase.offset)
                    .opacity(gainPhase == .shown ? 1 : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .animation(.snappy, value: page)
        .accessibilityElement(children: .combine)
        .onChange(of: page) { old, new in
            guard new > old else { return }
            celebrate(new - old)
        }
    }

    private var progress: Int? {
        guard let pageCount, pageCount > 0 else { return nil }
        return min(100, page * 100 / pageCount)
    }

    /// Lifts the pages just read off the line, holds them, then lets them go.
    private func celebrate(_ pages: Int) {
        gain = pages
        gainPhase = .low
        Task {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) { gainPhase = .shown }
            try? await Task.sleep(for: .seconds(1.6))
            withAnimation(.easeOut(duration: 0.6)) { gainPhase = .gone }
            try? await Task.sleep(for: .seconds(0.6))
            if gain == pages { gain = nil }
        }
    }

    private enum GainPhase {
        case low, shown, gone

        var offset: CGFloat {
            switch self {
            case .low: -6
            case .shown: -24
            case .gone: -38
            }
        }
    }
}

#Preview {
    @Previewable @State var page = 214
    VStack(alignment: .leading, spacing: 24) {
        ReadingPageLine(page: page, pageCount: 662)
        ReadingPageLine(page: 46)
        Button { page += 34 } label: { Text(verbatim: "+34") }
    }
    .padding(40)
    .background(.black)
}
