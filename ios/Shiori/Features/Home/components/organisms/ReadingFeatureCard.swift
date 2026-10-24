import SwiftUI

/// The book read now, at the head of "En cours" on a phone: its cover the
/// card's whole height on the leading edge, and beside it the text as the TV
/// app's card heads the episode playing — the saga over the title, how long it
/// has been open and how long it runs, how much is left on a small bar, then
/// the next step on Liquid Glass, and the way to its saga when it has one.
struct ReadingFeatureCard: View {
    let book: Book
    /// How long it has been open.
    let caption: String
    let onOpen: () -> Void
    let onFinish: () -> Void
    /// Opens the book's saga. Nil for a standalone book, which draws no button.
    var onOpenSeries: (() -> Void)?

    /// The text's height, which the cover stretches to.
    @State private var textHeight: CGFloat = 0

    private static let coverWidth: CGFloat = 96

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: onOpen) {
                // Edge to edge, the card's corners rounding it.
                BookCover(
                    book: book,
                    width: Self.coverWidth,
                    showsFormatBadge: false,
                    minHeight: textHeight,
                    cornerRadius: 0
                )
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 12) {
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
                            progressLine(progress)
                                .padding(.top, 8)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("home-reading-lead")
                actions
            }
            .padding(.vertical, 14)
            .padding(.trailing, 14)
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        }
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

    /// How long it has been open and how long it runs, then its format in an
    /// outlined tag.
    private var detailLine: some View {
        HStack(spacing: 6) {
            Text([caption, length].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Text(book.format == .audiobook ? String(localized: "Audio") : book.format.label)
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.white.opacity(0.75), lineWidth: 1) }
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize()
        }
    }

    private var length: String? {
        if let duration = book.durationLabel { return duration }
        return book.pageCount.map { String(localized: "\($0) pages") }
    }

    /// How far the recording got, on a small bar, and what is left to hear, as
    /// the TV app says the minutes left of an episode.
    private func progressLine(_ progress: Int) -> some View {
        HStack(spacing: 8) {
            Capsule()
                .fill(.white.opacity(0.3))
                .frame(width: 56, height: 4)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(.white)
                        .frame(width: 56 * CGFloat(min(max(progress, 0), 100)) / 100, height: 4)
                }
            Text(remaining(progress) ?? String(localized: "\(progress)% écouté"))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    /// The time left in the recording, when its length is known.
    private func remaining(_ progress: Int) -> String? {
        guard let total = book.durationMinutes else { return nil }
        let left = total * (100 - min(max(progress, 0), 100)) / 100
        let hours = left / 60
        let minutes = left % 60
        let label = hours == 0
            ? String(localized: "\(minutes) min")
            : minutes == 0 ? String(localized: "\(hours) h") : String(localized: "\(hours) h \(minutes)")
        return String(localized: "\(label) restantes")
    }

    /// The next step white, the saga on glass.
    private var actions: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                Button(action: onFinish) {
                    Label("Marquer lu", systemImage: "checkmark")
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
        caption: "depuis 2 j",
        onOpen: {}, onFinish: {}, onOpenSeries: {}
    )
    .padding()
}
