import SwiftUI

/// The full-screen player, on the app's one `AudiblePlayer`.
struct PlayerScreen: View {
    @Environment(AudiblePlayer.self) private var player
    @Environment(\.closePlayer) private var closePlayer
    /// The book of the title playing, once the player has closed.
    let onOpenBook: (String) -> Void
    /// What follows the title playing, asked again whenever it changes.
    @State private var queue: [ListeningQueueEntry]?

    var body: some View {
        if let item = PlayerPage.Item(player: player, queue: queue) {
            PlayerPage(item: item) { action in
                switch action {
                case .togglePlay: player.togglePlayPause()
                case let .skip(seconds): player.skip(by: seconds)
                case .previousChapter: player.previousChapter()
                case .nextChapter: player.nextChapter()
                case let .seek(position): player.seek(to: position)
                case let .sleep(minutes): player.toggleSleepTimer(minutes: minutes)
                case .openBook:
                    guard let bookID = player.title?.bookID else { return }
                    onOpenBook(bookID)
                    closePlayer?()
                case let .play(title): player.play(title)
                }
            }
            .task(id: player.title?.asin) {
                queue = nil
                do {
                    queue = try await player.upNext()
                } catch is CancellationError {
                } catch {
                    // The queue is a convenience: it stays empty rather than
                    // getting in the way of what plays.
                    queue = []
                }
            }
        } else {
            // Stopped from the lock screen while open: nothing left to show.
            Color.black.ignoresSafeArea().task { closePlayer?() }
        }
    }
}

/// The accessory over the tab bar, on the app's one `AudiblePlayer`. Drawn
/// only while a title is playing or paused: `isShown` gates the system slot.
struct PlayerAccessoryScreen: View {
    @Environment(AudiblePlayer.self) private var player
    let onOpen: () -> Void

    var body: some View {
        if let item = PlayerAccessory.Item(player: player) {
            PlayerAccessory(
                item: item,
                onOpen: onOpen,
                onTogglePlay: { player.togglePlayPause() },
                onSkipBack: { player.skip(by: -AudiblePlayer.skipInterval) }
            )
        }
    }
}

extension PlayerPage.Item {
    @MainActor init?(player: AudiblePlayer, queue: [ListeningQueueEntry]? = nil) {
        guard let title = player.title else { return nil }
        let failure: String? = if case let .failed(message) = player.phase { message } else { nil }
        self.init(
            title: title.title,
            subtitle: title.subtitle,
            coverURL: title.coverURL,
            progress: player.progress,
            isPlaying: player.isPlaying,
            isLoading: player.phase == .loading,
            failure: failure,
            sleepMinutes: player.sleepTimer?.minutes,
            sleepEndsAt: player.sleepTimer?.endsAt,
            hasBook: title.bookID != nil,
            queue: queue
        )
    }
}

extension PlayerAccessory.Item {
    @MainActor init?(player: AudiblePlayer) {
        guard let title = player.title else { return nil }
        let line: String? = switch player.phase {
        case .loading: player.duration > 0 ? ListeningText.accessoryLine(player.progress) : title.subtitle
        case .ready, .waiting: ListeningText.accessoryLine(player.progress)
        case let .failed(message): message
        }
        self.init(
            title: title.title,
            line: line,
            shortLine: player.phase == .ready || player.phase == .waiting ? ListeningText.shortLine(player.progress) : nil,
            coverURL: title.coverURL,
            isPlaying: player.isPlaying,
            isLoading: player.phase == .loading
        )
    }
}
