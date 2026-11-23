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
    /// A book of the queue, played in place of this one.
    case play(ListeningTitle)
}

/// The full-screen player, over its cover's colours: the cover, the title and
/// the series, the chapter's bar with where the listener is in it, the chapter
/// and ±30 s controls, the time left in the book, and the sleep timer set in
/// one touch. Under it, the queue: pulled up, the cover shrinks to a banner
/// over the bar and the controls, and the audiobooks that follow this one
/// are listed, each played with a touch.
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
        /// What follows this title; nil while it loads.
        var queue: [ListeningQueueEntry]?
    }

    let item: Item
    let onAction: (PlayerAction) -> Void

    /// Where a finger dragging the bar holds it, from 0 to 1.
    @State private var scrubbing: Double?
    @State private var isQueueOpen: Bool

    init(item: Item, isQueueOpen: Bool = false, onAction: @escaping (PlayerAction) -> Void) {
        self.item = item
        self.onAction = onAction
        _isQueueOpen = State(initialValue: isQueueOpen)
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if isQueueOpen {
                    queuePage
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    playerPage(width: proxy.size.width)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 32)
            .frame(width: proxy.size.width)
        }
        .foregroundStyle(.white)
        .background { backdrop }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Layouts

    private func playerPage(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            PlayerArtwork(url: item.coverURL, size: min(300, width - 102), cornerRadius: 12)
                .shadow(color: .black.opacity(0.45), radius: 25, y: 22)
                .padding(.top, 48)
            heading
                .padding(.top, 30)
            chapterBar
                .padding(.top, 22)
            controls
                .padding(.top, 26)
            if item.failure != nil {
                summary
                    .padding(.top, 22)
            }
            sleepTimer
                .padding(.top, 26)
            Spacer(minLength: 24)
            openQueueHandle
        }
    }

    /// The queue pulled up: the title as a banner, the bar and the controls
    /// kept, then what follows.
    private var queuePage: some View {
        VStack(spacing: 0) {
            banner
                .padding(.top, 40)
            chapterBar
                .padding(.top, 30)
            controls
                .padding(.top, 14)
            closeQueueHandle
                .padding(.top, 10)
            Text("À suivre")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
            queueList
                .padding(.top, 10)
        }
    }

    private func setQueueOpen(_ open: Bool) {
        withAnimation(.snappy) { isQueueOpen = open }
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
                bookLeft
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            bookButton
        }
    }

    /// The heading shrunk beside a small cover, over the pulled-up queue.
    private var banner: some View {
        HStack(alignment: .center, spacing: 14) {
            PlayerArtwork(url: item.coverURL, size: 64, cornerRadius: 8)
                .shadow(color: .black.opacity(0.4), radius: 10, y: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.title3.bold())
                    .lineLimit(1)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                bookLeft
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            bookButton
        }
    }

    /// "11h47 restantes · 46%", under the subtitle; nothing while the
    /// recording's length is unknown or it fails.
    @ViewBuilder
    private var bookLeft: some View {
        if item.failure == nil, item.progress.duration > 0 {
            Text(ListeningText.summary(item.progress))
                .contentTransition(.numericText())
                .font(.footnote.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
    }

    private var bookButton: some View {
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

    private var grabber: some View {
        Capsule()
            .fill(.white.opacity(0.5))
            .frame(width: 36, height: 5)
    }

    /// At the foot of the player: touched or pulled up, it opens the queue.
    private var openQueueHandle: some View {
        Button { setQueueOpen(true) } label: {
            VStack(spacing: 14) {
                grabber
                Text("À suivre")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height < -30 { setQueueOpen(true) }
            }
        )
    }

    /// Over the queue: touched or pulled down, it folds the queue away.
    private var closeQueueHandle: some View {
        Button { setQueueOpen(false) } label: {
            grabber
                .frame(maxWidth: .infinity, minHeight: 24)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 12).onEnded { value in
                if value.translation.height > 30 { setQueueOpen(false) }
            }
        )
        .accessibilityLabel(Text("Replier la file"))
    }

    @ViewBuilder
    private var queueList: some View {
        if let queue = item.queue {
            if queue.isEmpty {
                EmptyState(
                    systemImage: "text.line.first.and.arrowtriangle.forward",
                    title: "Rien à suivre",
                    message: "Les livres audio en cours et à lire s'enchaîneront ici, une fois ce livre fini."
                )
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(queue) { entry in
                            queueRow(entry)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        } else {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func queueRow(_ entry: ListeningQueueEntry) -> some View {
        Button {
            setQueueOpen(false)
            onAction(.play(entry.title))
        } label: {
            HStack(spacing: 14) {
                PlayerArtwork(url: entry.title.coverURL, size: 56, cornerRadius: 6)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(entry.title.title)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let heard = entry.heard {
                            Pill(text: (Double(heard) / 100).formatted(.percent), font: .caption.weight(.semibold))
                        }
                    }
                    if let subtitle = entry.title.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(height: 0.5)
                }
            }
            .frame(height: 76)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Écouter \(entry.title.title)"))
    }

    /// Why it does not play; the time left in the book sits on the chapter's
    /// line. Downloading and waiting for the network show nothing: they
    /// happen in silence.
    private var summary: some View {
        Text(item.failure ?? "")
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

    func withQueue(_ queue: [ListeningQueueEntry]?) -> Self {
        var item = self
        item.queue = queue
        return item
    }
}

#Preview("Queue") {
    PlayerPage(item: .preview.withQueue(ListeningQueueEntry.previews), isQueueOpen: true) { _ in }
}

#Preview("Queue empty") {
    PlayerPage(item: .preview.withQueue([]), isQueueOpen: true) { _ in }
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
