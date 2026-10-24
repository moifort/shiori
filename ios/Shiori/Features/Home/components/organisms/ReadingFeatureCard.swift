import SwiftUI

/// The book read now, at the head of "En cours" on a phone, as the TV app's
/// card heads the episode playing: the saga over the title, a line saying what
/// it is, the synopsis led by its volume, how far it got and how long it runs,
/// then the next step on Liquid Glass — all over the cover, sharp on the
/// trailing side and fading into its own colours under the text.
struct ReadingFeatureCard: View {
    let book: Book
    /// How long it has been open, or how far the recording got.
    let caption: String
    let onOpen: () -> Void
    let onFinish: () -> Void
    let onRate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(overline)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                    Text(book.title)
                        .font(.title2.weight(.bold))
                        .lineLimit(2)
                    metaLine
                        .padding(.top, 10)
                    if let synopsis = book.synopsis, !synopsis.isEmpty {
                        synopsisText(synopsis)
                            .padding(.top, 10)
                    }
                    detailLine
                        .padding(.top, 10)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("home-reading-lead")
            actions
        }
        .padding(18)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .background { artwork }
        .clipShape(.rect(cornerRadius: 22))
    }

    /// Over the title: the saga, as the TV app names the show over the
    /// episode, else who wrote it.
    private var overline: String {
        book.series?.name ?? book.authorLine
    }

    /// What it is, after its format's mark: the genre, and the author when the
    /// saga took the line above.
    private var metaLine: some View {
        HStack(spacing: 8) {
            Image(systemName: book.format.symbol)
                .font(.caption.weight(.semibold))
                .frame(width: 26, height: 26)
                .background(.white.opacity(0.18), in: .circle)
            Text([book.genre?.label, book.series == nil ? nil : book.authorLine]
                .compactMap { $0 }
                .joined(separator: " · "))
                .font(.subheadline)
                .lineLimit(1)
        }
    }

    /// The synopsis led by its volume in bold, as the TV app leads with the
    /// episode's number.
    private func synopsisText(_ synopsis: String) -> some View {
        Group {
            if let volume = book.series?.volume {
                Text("\(Text("Tome \(volume) :").bold()) \(synopsis)")
            } else {
                Text(synopsis)
            }
        }
        .font(.subheadline)
        .foregroundStyle(.white.opacity(0.85))
        .lineLimit(3)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// How far it got and how long it runs, then its format in an outlined tag.
    private var detailLine: some View {
        HStack(spacing: 8) {
            Text([caption, length].compactMap { $0 }.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Text(book.format.label)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(.white.opacity(0.75), lineWidth: 1) }
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize()
        }
    }

    private var length: String? {
        if let duration = book.durationLabel { return duration }
        return book.pageCount.map { String(localized: "\($0) pages") }
    }

    /// The next step white, the rating on glass, side by side and as wide.
    private var actions: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onFinish) {
                    Label("Marquer lu", systemImage: "checkmark")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                Button(action: onRate) {
                    Label("Noter", systemImage: "star")
                        .font(.headline)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.extraLarge)
        }
    }

    /// The cover's colours across the card, the cover itself sharp on the
    /// trailing side, and the shade that keeps the text white over both.
    private var artwork: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                CoverBackdrop(url: book.coverURL, ground: .clear)
                if let url = book.coverURL {
                    CoverImage(url: url) {
                        Color.clear
                    } fallback: {
                        Color.clear
                    }
                    .frame(width: proxy.size.height * 2 / 3, height: proxy.size.height)
                    .clipped()
                    // Melting into the colours on its leading side.
                    .mask {
                        LinearGradient(
                            stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
                LinearGradient(
                    colors: [.black.opacity(0.75), .black.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ReadingFeatureCard(
        book: Book(
            id: "1", title: "La Peur du sage", authors: ["Patrick Rothfuss"],
            synopsis: "Kvothe poursuit son récit : l'Université, la cour du Maer, et les Chandrian toujours plus près.",
            genre: .fantasy, pageCount: 1_000,
            series: SeriesMembership(id: "kk", name: "Chronique du tueur de roi", volume: 2, kind: .main),
            coverURL: Book.preview.coverURL, status: .reading
        ),
        caption: "depuis 12 j",
        onOpen: {}, onFinish: {}, onRate: {}
    )
    .padding()
}
