import SwiftUI

/// The book read now, at the head of "En cours" on a phone: its cover the
/// card's whole height on the leading edge, and beside it the text as the TV
/// app's card heads the episode playing — the saga over the title, how long it
/// has been open and how long it runs, how much is left on a small bar, then,
/// held to the card's foot, the next step on Liquid Glass and the way to its
/// saga when it has one.
struct ReadingFeatureCard: View {
    let book: Book
    /// How long it has been open.
    let caption: String
    let onOpen: () -> Void
    let onFinish: () -> Void
    /// Opens the book's saga. Nil for a standalone book, which draws no button.
    var onOpenSeries: (() -> Void)?

    /// The text's and the buttons' heights, which the cover stretches to.
    @State private var leadHeight: CGFloat = 0
    @State private var actionsHeight: CGFloat = 0

    private static let actionsSpacing: CGFloat = 12
    private static let verticalPadding: CGFloat = 14

    private static let coverWidth: CGFloat = 96

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onOpen) {
                // Edge to edge, the card's corners rounding it.
                BookCover(
                    book: book,
                    width: Self.coverWidth,
                    showsFormatBadge: false,
                    minHeight: leadHeight + Self.actionsSpacing + actionsHeight
                        + Self.verticalPadding * 2,
                    cornerRadius: 0
                )
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 0) {
                Button(action: onOpen) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(overline)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                        Text(book.title)
                            .font(.title3.weight(.bold))
                            .lineLimit(2)
                        detailLine
                            .padding(.top, 6)
                        if let progress = book.listeningProgress {
                            ListeningProgressLine(progress: progress, durationMinutes: book.durationMinutes)
                                .padding(.top, 8)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-reading-lead")
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { leadHeight = $0 }
                // The buttons sit at the card's foot when the cover runs
                // taller than the text.
                Spacer(minLength: Self.actionsSpacing)
                actions
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { actionsHeight = $0 }
            }
            .padding(.vertical, Self.verticalPadding)
            .padding(.trailing, 14)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        // Sized to its tallest side, so the text column can fill the cover's height.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.colorScheme, .dark)
        .background {
            CoverBackdrop(url: book.coverURL, ground: .clear)
        }
        .clipShape(.rect(cornerRadius: 18))
    }

    /// Over the title: the saga, as the TV app names the show over the
    /// episode, else who wrote it.
    private var overline: String {
        guard let series = book.series else { return book.authorLine }
        guard let volume = series.volume else { return series.name }
        return "\(series.name) · \(String(localized: "Tome \(volume)"))"
    }

    /// How long it has been open and how long it runs, then an outlined tag
    /// when it is listened to: a printed book needs none.
    private var detailLine: some View {
        HStack(spacing: 6) {
            Text([caption, length].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            if book.format == .audiobook {
                OutlinedTag(text: String(localized: "Audio").uppercased())
            }
        }
    }

    private var length: String? {
        if let duration = book.durationLabel { return duration }
        return book.pageCount.map { String(localized: "\($0) pages") }
    }

    /// The next step white, the saga on glass.
    private var actions: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onFinish) {
                    Label("Marquer lu", systemImage: "checkmark")
                        .labelStyle(.caption)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)
                if let onOpenSeries {
                    Button(action: onOpenSeries) {
                        Text("Voir la série")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .buttonStyle(.glass)
                }
            }
            .controlSize(.small)
        }
        .fixedSize()
    }
}

#Preview {
    ReadingFeatureCard(
        book: Book(
            id: "1", title: "Endymion", authors: ["Dan Simmons"], format: .audiobook,
            durationMinutes: 1310, listeningProgress: 46,
            series: SeriesMembership(id: "h", name: "Les Cantos d'Hypérion", volume: 3, kind: .main),
            coverURL: Book.preview.coverURL, status: .reading
        ),
        caption: "depuis 2j",
        onOpen: {}, onFinish: {}, onOpenSeries: {}
    )
    .padding()
}
