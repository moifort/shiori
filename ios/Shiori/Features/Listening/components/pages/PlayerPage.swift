import SwiftUI

/// Everything the full-screen player can ask for.
enum PlayerAction {
    case togglePlay
    case skip(TimeInterval)
    case previousChapter
    case nextChapter
    case seek(TimeInterval)
    case sleep(minutes: Int)
    /// The three dots: the player gives way to the book's page.
    case openBook
}

/// The full-screen player, over its cover's colours: the cover, the title and
/// the series, the chapter's bar with where the listener is in it, the chapter
/// and ±30 s controls, the time left in the book, and the sleep timer set in
/// one touch.
struct PlayerPage: View {
    struct Item: Hashable {
        let title: String
        let subtitle: String?
        let coverURL: URL?
        let progress: ListeningProgress
        let isPlaying: Bool
        let isLoading: Bool
        /// Why it does not play, in place of the time left.
        let failure: String?
        /// The sleep timer's choice, while it runs.
        let sleepMinutes: Int?
        /// Whether the title has a book in the library to open.
        var hasBook = true
    }

    let item: Item
    let onAction: (PlayerAction) -> Void

    /// Where a finger dragging the bar holds it, from 0 to 1.
    @State private var scrubbing: Double?

    var body: some View {
        GeometryReader { proxy in
            let art = min(300, proxy.size.width - 102)
            VStack(spacing: 0) {
                PlayerArtwork(url: item.coverURL, size: art, cornerRadius: 12)
                    .shadow(color: .black.opacity(0.45), radius: 25, y: 22)
                    .padding(.top, 60)
                heading
                    .padding(.top, 36)
                chapterBar
                    .padding(.top, 28)
                controls
                    .padding(.top, 34)
                summary
                    .padding(.top, 22)
                sleepTimer
                    .padding(.top, 40)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 32)
            .frame(width: proxy.size.width)
        }
        .foregroundStyle(.white)
        .background { backdrop }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Parts

    private var backdrop: some View {
        Color.black
            .overlay {
                if let url = item.coverURL {
                    CoverEffectImage(url: url, effect: .backdrop) { Color.clear }
                        .scaleEffect(1.6)
                        .brightness(-0.1)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var heading: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.title2.bold())
                    .lineLimit(2)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { onAction(.openBook) } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .disabled(!item.hasBook)
            .accessibilityLabel(Text("Fiche du livre"))
        }
    }

    /// The time left in the book, or why it does not play. Downloading
    /// and waiting for the network show nothing: they happen in silence.
    private var summary: some View {
        Text(item.failure ?? ListeningText.summary(item.progress))
            .contentTransition(.numericText())
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.7))
    }

    private var chapterBar: some View {
        let progress = item.progress
        let fraction = scrubbing ?? progress.chapterFraction
        let chapter = progress.chapter
        let shownElapsed = chapter.map { fraction * $0.length } ?? progress.chapterElapsed
        let shownRemaining = chapter.map { $0.length - shownElapsed } ?? progress.chapterRemaining
        return VStack(spacing: 8) {
            GeometryReader { bar in
                Capsule()
                    .fill(.white.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: bar.size.width * fraction)
                    }
                    .frame(height: scrubbing == nil ? 6 : 10)
                    .frame(maxHeight: .infinity)
                    .contentShape(.rect)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                scrubbing = min(1, max(0, value.location.x / bar.size.width))
                            }
                            .onEnded { _ in
                                if let scrubbing, let chapter {
                                    onAction(.seek(chapter.start + scrubbing * chapter.length))
                                }
                                scrubbing = nil
                            }
                    )
                    .animation(.snappy, value: scrubbing == nil)
            }
            .frame(height: 22)
            .disabled(item.isLoading || chapter == nil)
            .accessibilityElement()
            .accessibilityLabel(Text("Position dans le chapitre"))
            .accessibilityValue(Text(ListeningText.clock(shownElapsed)))

            HStack {
                Text(ListeningText.clock(shownElapsed))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let chapterLine = ListeningText.chapterOfCount(progress) {
                    Text(chapterLine)
                        .foregroundStyle(.white)
                        .layoutPriority(1)
                }
                Text("−\(ListeningText.clock(shownRemaining))")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.caption.weight(.semibold).monospacedDigit())
            .foregroundStyle(.white.opacity(0.7))
            .padding(.top, -6)
        }
    }

    private var controls: some View {
        HStack {
            controlButton("backward.end.fill", size: 26, label: "Chapitre précédent") {
                onAction(.previousChapter)
            }
            Spacer()
            controlButton("gobackward.30", size: 34, label: "Reculer de 30 secondes") {
                onAction(.skip(-AudiblePlayer.skipInterval))
            }
            Spacer()
            Button { onAction(.togglePlay) } label: {
                Group {
                    if item.isLoading {
                        ProgressView().controlSize(.large).tint(.white)
                    } else {
                        Image(systemName: item.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 50))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 80, height: 80)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(item.isLoading)
            .accessibilityLabel(Text(item.isPlaying ? "Pause" : "Lecture"))
            Spacer()
            controlButton("goforward.30", size: 34, label: "Avancer de 30 secondes") {
                onAction(.skip(AudiblePlayer.skipInterval))
            }
            Spacer()
            controlButton("forward.end.fill", size: 26, label: "Chapitre suivant") {
                onAction(.nextChapter)
            }
            .disabled(item.progress.nextChapterStart == nil)
        }
        .padding(.horizontal, -2)
    }

    private func controlButton(
        _ symbol: String,
        size: CGFloat,
        label: LocalizedStringKey,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: 52, height: 52)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(item.isLoading)
        .accessibilityLabel(Text(label))
    }

    private var sleepTimer: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon")
                .font(.system(size: 20, weight: .medium))
                .iconGesture(.rock, trigger: item.sleepMinutes)
                .padding(.trailing, 4)
                .accessibilityHidden(true)
            ForEach(AudiblePlayer.sleepChoices, id: \.self) { minutes in
                let isOn = item.sleepMinutes == minutes
                Button { onAction(.sleep(minutes: minutes)) } label: {
                    Text("\(minutes) min")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.action(isOn ? .white : .glass, height: 40))
                .animation(.snappy, value: isOn)
                .accessibilityLabel(Text("Arrêter dans \(minutes) minutes"))
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}

extension PlayerPage.Item {
    static let preview = PlayerPage.Item(
        title: ListeningTitle.preview.title,
        subtitle: ListeningTitle.preview.subtitle,
        coverURL: ListeningTitle.preview.coverURL,
        progress: .preview,
        isPlaying: true,
        isLoading: false,
        failure: nil,
        sleepMinutes: nil
    )
}

#Preview("Playing") {
    PlayerPage(item: .preview) { _ in }
}

#Preview("Loading") {
    PlayerPage(
        item: PlayerPage.Item(
            title: "Endymion",
            subtitle: "Les Cantos d'Hypérion · Tome 3",
            coverURL: ListeningTitle.preview.coverURL,
            progress: ListeningProgress(elapsed: 0, duration: 0, chapters: []),
            isPlaying: false,
            isLoading: true,
            failure: nil,
            sleepMinutes: nil
        )
    ) { _ in }
}

#Preview("Sleep timer on") {
    PlayerPage(
        item: PlayerPage.Item(
            title: "Endymion",
            subtitle: "Les Cantos d'Hypérion · Tome 3",
            coverURL: ListeningTitle.preview.coverURL,
            progress: .preview,
            isPlaying: true,
            isLoading: false,
            failure: nil,
            sleepMinutes: 20
        )
    ) { _ in }
}
