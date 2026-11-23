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
/// one touch. Under it, the queue: pulled up, in the same sheet, the player
/// shrinks with the finger (the cover to a banner, the controls smaller, the
/// sleep timer gone) and the audiobooks that follow this one rise in its
/// place, each played with a touch.
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
    /// How far the queue is pulled up: 0 is the whole player, 1 the queue
    /// over the shrunk player. A finger on the handle moves it continuously.
    @State private var queueProgress: CGFloat
    /// Where the queue stood when the finger came down.
    @State private var dragStart: CGFloat?
    /// Whether the queue's list is scrolled to its top, where pulling it down
    /// folds the queue away.
    @State private var isListAtTop = true

    init(item: Item, isQueueOpen: Bool = false, onAction: @escaping (PlayerAction) -> Void) {
        self.init(item: item, queueProgress: isQueueOpen ? 1 : 0, onAction: onAction)
    }

    /// Opened partway, as a finger leaves it: for previews.
    init(item: Item, queueProgress: CGFloat, onAction: @escaping (PlayerAction) -> Void) {
        self.item = item
        self.onAction = onAction
        _queueProgress = State(initialValue: queueProgress)
    }

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width - 64
            let progress = queueProgress
            let full = QueueRevealLayout.artworkSize(width: width)
            let scale = mix(1, QueueRevealLayout.bannerArtwork / full, progress)
            // The handle travels from the foot of the page to under the
            // controls: the finger and the handle move together.
            let travel = max(240, proxy.size.height - 330)
            QueueRevealLayout(progress: progress) {
                PlayerArtwork(url: item.coverURL, size: full, cornerRadius: mix(12, 8, progress) / scale)
                    .shadow(color: .black.opacity(0.45), radius: mix(25, 10, progress) / scale, y: mix(22, 8, progress) / scale)
                    .scaleEffect(scale, anchor: .topLeading)
                heading
                    .opacity(ramp(progress, from: 0.3, to: 0))
                    .allowsHitTesting(progress < 0.3)
                banner
                    .opacity(ramp(progress, from: 0.55, to: 1))
                    .allowsHitTesting(progress >= 0.5)
                    .accessibilityHidden(progress < 0.5)
                chapterBar
                controls
                    .scaleEffect(mix(1, QueueRevealLayout.controlsScale, progress), anchor: .top)
                VStack(spacing: 22) {
                    if item.failure != nil {
                        summary
                    }
                    sleepTimer
                }
                .opacity(ramp(progress, from: 0.3, to: 0))
                .allowsHitTesting(progress == 0)
                .accessibilityHidden(progress > 0)
                openQueueHandle
                    .opacity(ramp(progress, from: 0.3, to: 0))
                    .allowsHitTesting(progress < 0.5)
                    .accessibilityHidden(progress >= 0.5)
                    .gesture(queueDrag(travel: travel))
                queueHeader
                    .opacity(ramp(progress, from: 0.2, to: 0.55))
                    .allowsHitTesting(progress >= 0.5)
                    .accessibilityHidden(progress < 0.5)
                    .gesture(queueDrag(travel: travel))
                queueList
                    .opacity(Double(progress))
                    .allowsHitTesting(progress == 1)
                    .accessibilityHidden(progress < 1)
                    .simultaneousGesture(listPullDown(travel: travel))
            }
            .padding(.horizontal, 32)
            .frame(width: proxy.size.width)
        }
        .foregroundStyle(.white)
        .background { backdrop }
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Pulling the queue

    private func setQueueOpen(_ open: Bool) {
        withAnimation(.snappy) { queueProgress = open ? 1 : 0 }
    }

    /// On the handle, either way: the player shrinks and the queue rises with
    /// the finger; let go past halfway, or flicked, it finishes the trip.
    private func queueDrag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .global)
            .onChanged { value in
                let start = dragStart ?? queueProgress
                dragStart = start
                queueProgress = clamp(start - value.translation.height / travel)
            }
            .onEnded { value in
                let start = dragStart ?? queueProgress
                dragStart = nil
                setQueueOpen(clamp(start - value.predictedEndTranslation.height / travel) > 0.5)
            }
    }

    /// The list pulled down from its top folds the queue away the same way.
    private func listPullDown(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard queueProgress > 0, dragStart != nil || (isListAtTop && value.translation.height > 0) else { return }
                let start = dragStart ?? 1
                dragStart = start
                queueProgress = clamp(start - max(0, value.translation.height) / travel)
            }
            .onEnded { value in
                guard let start = dragStart else { return }
                dragStart = nil
                setQueueOpen(clamp(start - value.predictedEndTranslation.height / travel) > 0.5)
            }
    }

    private func clamp(_ value: CGFloat) -> CGFloat { min(1, max(0, value)) }

    private func mix(_ from: CGFloat, _ to: CGFloat, _ progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    /// An opacity along the pull. With `to` 0, it fades out until `from`;
    /// otherwise it fades in between `from` and `to`.
    private func ramp(_ progress: CGFloat, from start: CGFloat, to end: CGFloat) -> Double {
        if end == 0 { return Double(max(0, 1 - progress / start)) }
        return Double(min(1, max(0, (progress - start) / (end - start))))
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

    /// The heading shrunk beside the small cover, over the pulled-up queue.
    private var banner: some View {
        HStack(alignment: .center, spacing: 14) {
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

    /// At the foot of the player: touched, it opens the queue; pulled up,
    /// the queue follows the finger.
    private var openQueueHandle: some View {
        VStack(spacing: 14) {
            grabber
            Text("À suivre")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
        .contentShape(.rect)
        // Not a Button: a button would fire at the end of a short pull and
        // open the queue the finger meant to let fall back.
        .onTapGesture { setQueueOpen(true) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { setQueueOpen(true) }
    }

    /// Over the queue: touched, it folds the queue away; pulled down, the
    /// player grows back with the finger.
    private var queueHeader: some View {
        VStack(spacing: 8) {
            grabber
                .frame(maxWidth: .infinity, minHeight: 24)
            Text("À suivre")
                .font(.title3.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .contentShape(.rect)
        .onTapGesture { setQueueOpen(false) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Replier la file"))
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { setQueueOpen(false) }
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
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y <= -geometry.contentInsets.top + 1
                } action: { _, atTop in
                    isListAtTop = atTop
                }
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

/// Lays the player out between its two states, `progress` from 0 (the whole
/// player, the queue's handle at the foot) to 1 (the cover shrunk beside the
/// title, the controls under it, the queue below). Every part is measured in
/// both states and placed in between, so a finger moves them all at once.
/// Subviews, in order: cover, heading, banner, chapter bar, controls, sleep
/// timer, the handle at the foot, the queue's header, the queue's list.
private struct QueueRevealLayout: Layout {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    static let bannerArtwork: CGFloat = 64
    static let controlsScale: CGFloat = 0.8
    private static let handleHeight: CGFloat = 60

    static func artworkSize(width: CGFloat) -> CGFloat {
        min(300, width - 38)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 9 else { return }
        let p = min(1, max(0, progress))
        func mix(_ from: CGFloat, _ to: CGFloat) -> CGFloat { from + (to - from) * p }
        func height(_ index: Int, width: CGFloat) -> CGFloat {
            subviews[index].sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        func place(_ index: Int, x: CGFloat = 0, y: CGFloat, width: CGFloat, height: CGFloat? = nil) {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: width, height: height)
            )
        }

        let width = bounds.width
        let full = Self.artworkSize(width: width)
        let small = Self.bannerArtwork
        let headingHeight = height(1, width: width)
        let bannerHeight = height(2, width: width - small - 14)
        let barHeight = height(3, width: width)
        let controlsHeight = height(4, width: width)
        let headerHeight = height(7, width: width)

        // The whole player.
        let foldedCover: CGFloat = 48
        let foldedHandle = bounds.height - Self.handleHeight
        // The queue pulled up.
        let openCover: CGFloat = 40
        let openBar = openCover + small + 30
        let openControls = openBar + barHeight + 14
        let openHeader = openControls + controlsHeight * Self.controlsScale + 10

        // Every part hangs from the one above it, so nothing crosses on the
        // way: the heading's room closes as it fades.
        let coverSide = mix(full, small)
        let coverY = mix(foldedCover, openCover)
        let coverBottom = coverY + coverSide
        place(0, x: mix((width - full) / 2, 0), y: coverY, width: full, height: full)
        place(1, y: coverBottom + 30, width: width)
        let bannerLeft = coverSide + 14
        place(2, x: bannerLeft, y: coverY + (coverSide - bannerHeight) / 2, width: max(0, width - bannerLeft))
        let barY = coverBottom + mix(30 + headingHeight + 22, 30)
        place(3, y: barY, width: width)
        let controlsY = barY + barHeight + mix(26, 14)
        place(4, y: controlsY, width: width)
        let controlsShown = controlsHeight * mix(1, Self.controlsScale)
        place(5, y: controlsY + controlsShown + 26, width: width)
        let handleY = mix(foldedHandle, openHeader)
        place(6, y: handleY, width: width, height: Self.handleHeight)
        place(7, y: handleY, width: width)
        let listY = handleY + headerHeight + 10
        place(8, y: listY, width: width, height: max(0, bounds.height - listY))
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

#Preview("Queue halfway") {
    PlayerPage(item: .preview.withQueue(ListeningQueueEntry.previews), queueProgress: 0.45) { _ in }
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
