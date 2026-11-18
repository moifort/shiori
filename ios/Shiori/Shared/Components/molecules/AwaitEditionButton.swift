import SwiftUI

/// What may be awaited of a book the reader does not hold, and what is: its
/// translation and its recording in the app's language, each watched for and
/// announced the day it is out.
struct EditionWatch: Equatable, Sendable {
    /// Every edition the page offers to await, awaited or not, translation
    /// first.
    var offered: [ReleaseFormat]
    var awaited: Set<ReleaseFormat>

    init(offered: [ReleaseFormat], awaited: Set<ReleaseFormat>) {
        self.offered = ReleaseFormat.allCases.filter { offered.contains($0) || awaited.contains($0) }
        self.awaited = awaited
    }

    /// Nothing to await and nothing awaited: the button is left out.
    var isEmpty: Bool { offered.isEmpty }
}

/// "Guetter", the book page's own button beside "Envies" and the "+": it says
/// what it watches for once it does — "Traduction", "Audio", or both icons
/// over "Guetté" — so the reader never wonders which edition a tap awaited.
/// With one edition on offer a tap awaits it and a second gives it up, as
/// "Envies" does; with two it opens a menu that ticks each one awaited. Always
/// on glass, secondary: the wish list keeps the white.
struct AwaitEditionButton: View {
    let watch: EditionWatch
    var height: CGFloat = 50
    /// The server is answering: a spinner in the label's place.
    var isWorking = false
    let onToggle: (ReleaseFormat) -> Void

    var body: some View {
        Group {
            if watch.offered.count == 1, let format = watch.offered.first {
                Button { onToggle(format) } label: { label }
            } else {
                Menu {
                    ForEach(watch.offered) { format in
                        Toggle(isOn: Binding(
                            get: { watch.awaited.contains(format) },
                            set: { _ in onToggle(format) }
                        )) {
                            Label(format.watchTitle, systemImage: format.watchSymbol)
                        }
                        .accessibilityIdentifier("await-\(format.rawValue)")
                    }
                } label: {
                    label
                }
                .menuStyle(.button)
            }
        }
        .buttonStyle(ActionButtonStyle(fill: .glass, height: height))
        .disabled(isWorking)
        .animation(.bouncy(duration: 0.35), value: watch.awaited)
        .sensoryFeedback(trigger: watch.awaited) { old, new in
            new.count > old.count ? .success : .impact(weight: .light)
        }
        .accessibilityLabel(Text(accessibilityTitle))
        .accessibilityIdentifier("await-button")
    }

    private var label: some View {
        HStack(spacing: 8) {
            icons
                .iconGesture(.sweep, trigger: watch.awaited.count)
            Text(title)
                .contentTransition(.opacity)
        }
        .font(.headline)
        .lineLimit(1)
        .fixedSize()
        .opacity(isWorking ? 0 : 1)
        .overlay { if isWorking { ProgressView() } }
    }

    @ViewBuilder private var icons: some View {
        if watch.awaited.isEmpty {
            Image(systemName: "binoculars")
        } else {
            HStack(spacing: 4) {
                ForEach(watch.offered.filter { watch.awaited.contains($0) }) { format in
                    Image(systemName: format.awaitedSymbol)
                }
            }
        }
    }

    /// "Guetter" while nothing is; the edition's name once one is; "Guetté"
    /// beside both icons once both are.
    private var title: LocalizedStringKey {
        switch watch.awaited.count {
        case 0: "Guetter"
        case 1: watch.awaited.contains(.book) ? "Traduction" : "Audio"
        default: "Guetté"
        }
    }

    private var accessibilityTitle: String {
        switch watch.awaited.count {
        case 0: String(localized: "Guetter")
        case 1:
            watch.awaited.contains(.book)
                ? String(localized: "Traduction guettée")
                : String(localized: "Audio guetté")
        default: String(localized: "Traduction et audio guettés")
        }
    }
}

extension ReleaseFormat {
    /// The edition as the "Guetter" menu names it.
    var watchTitle: LocalizedStringKey {
        switch self {
        case .book: "La traduction"
        case .audiobook: "L'audio"
        }
    }

    /// Its icon there.
    var watchSymbol: String {
        switch self {
        case .book: "binoculars"
        case .audiobook: "headphones"
        }
    }

    /// Its icon on the button once awaited: the binoculars filled; the
    /// headphones have no filled form.
    var awaitedSymbol: String {
        switch self {
        case .book: "binoculars.fill"
        case .audiobook: "headphones"
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        AwaitEditionButton(watch: EditionWatch(offered: [.book, .audiobook], awaited: [])) { _ in }
        AwaitEditionButton(watch: EditionWatch(offered: [.book, .audiobook], awaited: [.book])) { _ in }
        AwaitEditionButton(watch: EditionWatch(offered: [.book, .audiobook], awaited: [.audiobook])) { _ in }
        AwaitEditionButton(watch: EditionWatch(offered: [.book, .audiobook], awaited: [.book, .audiobook])) { _ in }
        AwaitEditionButton(watch: EditionWatch(offered: [.audiobook], awaited: [])) { _ in }
    }
    .padding()
    .background(.black)
}
