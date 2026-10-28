import SwiftUI

/// Where the reader is in a printed or digital book, as the hero draws a
/// recording's progress: a small white bar, then "page 214 · 32%". When the
/// page moves on, the pages just read rise off the line — "+34 pages" — and
/// the bar and the figure move to the new page under them.
///
/// The line takes the page even before there is one, so the first page
/// recorded rises off it too, and it waits for the sheet the page was typed
/// in to slide away: the server answers while the sheet still covers the
/// line, and the reader would never see it move.
struct ReadingPageLine: View {
    /// The page reached; nil draws nothing.
    let page: Int?
    /// The book's length, for the bar and the share. Nil says the page alone.
    var pageCount: Int?
    /// Opens the page sheet from the line. Nil draws the line alone.
    var onOpen: (() -> Void)? = nil

    /// The page drawn, which follows `page` once the sheet is gone.
    @State private var shown: Int?
    /// The pages just read, risen off the line while they show.
    @State private var gain: Int?
    /// Where the pages just read are in their rise: low and hidden, shown,
    /// then gone above.
    @State private var gainPhase = GainPhase.low

    private static let width: CGFloat = 56
    /// How long a sheet takes to slide away, which the line waits out.
    private static let sheetDismissal: Duration = .milliseconds(550)

    init(page: Int?, pageCount: Int? = nil, onOpen: (() -> Void)? = nil) {
        self.page = page
        self.pageCount = pageCount
        self.onOpen = onOpen
        _shown = State(initialValue: page)
    }

    var body: some View {
        Group {
            if let shown {
                if let onOpen {
                    Button(action: onOpen) { line(shown).contentShape(.rect) }
                        .buttonStyle(.plain)
                        .accessibilityHint(Text("Modifie la page où vous en êtes"))
                        .accessibilityIdentifier("book-reading-page")
                } else {
                    line(shown)
                }
            }
        }
        .onChange(of: page) { old, new in
            Task {
                try? await Task.sleep(for: Self.sheetDismissal)
                withAnimation(.snappy) { shown = new }
                if let new, new > (old ?? 0) { celebrate(new - (old ?? 0)) }
            }
        }
    }

    private func line(_ page: Int) -> some View {
        let progress = progress(of: page)
        return HStack(spacing: 8) {
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
        .accessibilityElement(children: .combine)
    }

    private func progress(of page: Int) -> Int? {
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
    @Previewable @State var page: Int? = nil
    VStack(alignment: .leading, spacing: 24) {
        ReadingPageLine(page: page, pageCount: 662)
        ReadingPageLine(page: 46)
        Button { page = (page ?? 180) + 34 } label: { Text(verbatim: "+34") }
    }
    .padding(40)
    .background(.black)
}
