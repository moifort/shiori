import Foundation

/// What the play button of an Audible audiobook says, on its page and on its
/// "En cours" card: listen to it, take it up again, pause it, or hear it again.
enum ListeningButtonState: Hashable, Sendable {
    /// Never opened on any Audible player: from the start.
    case listen
    /// Under way: from where the reader stopped, here or on Audible.
    case resume
    /// Playing in Shiori now.
    case pause
    /// Finished: from the start again.
    case relisten

    var title: LocalizedStringResource {
        switch self {
        case .listen: "Écouter"
        case .resume: "Reprendre"
        case .pause: "Pause"
        case .relisten: "Réécouter"
        }
    }

    var systemImage: String {
        switch self {
        case .listen, .resume: "play.fill"
        case .pause: "pause.fill"
        case .relisten: "arrow.counterclockwise"
        }
    }

    /// The state of a book's button, or nil when it plays nothing: a paper
    /// book, an audiobook with no Audible page, or a screen given no player (a preview).
    @MainActor static func of(_ book: Book, player: AudiblePlayer?) -> ListeningButtonState? {
        guard let player, let title = ListeningTitle(book: book) else { return nil }
        let current = player.title?.asin == title.asin
        return of(
            status: book.status,
            progress: book.listeningProgress,
            isCurrent: current,
            isPlaying: current && player.isPlaying
        )
    }

    /// The rule itself, apart from the player, so it is tested on its own.
    static func of(status: ReadingStatus, progress: Int?, isCurrent: Bool, isPlaying: Bool) -> ListeningButtonState {
        if isPlaying { return .pause }
        if isCurrent { return .resume }
        if status == .read { return .relisten }
        if status == .reading || (progress ?? 0) > 0 { return .resume }
        return .listen
    }
}

extension AudiblePlayer {
    /// What a tap on a book's play button does, given what the button said.
    func press(_ state: ListeningButtonState, on book: Book) {
        guard let title = ListeningTitle(book: book) else { return }
        switch state {
        case .pause: pause()
        case .resume, .listen: play(title)
        case .relisten: play(title, fromStart: true)
        }
    }
}
