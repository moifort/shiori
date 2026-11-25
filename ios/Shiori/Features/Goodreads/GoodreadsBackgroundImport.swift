import Foundation
import Observation

/// A Goodreads import under way, kept beyond the screen that started it: the
/// books are written in one request, then their covers are sought a pass at a
/// time while the app is open. The onboarding's preparation checklist and the
/// import's own progress page both read it, and the reader may close either:
/// the work goes on. A cover never sought stays the app's typeset stand-in,
/// and the next import picks the rest up.
@MainActor
@Observable
final class GoodreadsBackgroundImport {
    static let shared = GoodreadsBackgroundImport()

    enum Phase: Equatable {
        case idle
        /// The books are being written.
        case importing
        /// The books are in; their covers are being sought.
        case seekingCovers
        case finished
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var outcome: GoodreadsImportOutcome?
    /// How many books still wait for their cover to be sought.
    private(set) var coversRemaining = 0
    /// How many covers were found so far.
    private(set) var coversFound = 0

    /// Whether anything is still running.
    var isRunning: Bool { phase == .importing || phase == .seekingCovers }

    /// How far the import has got, books written then covers sought, from 0 to 1.
    var progress: Double {
        guard let outcome else { return phase == .finished ? 1 : 0 }
        let total = max(outcome.pendingCovers, 1)
        return 0.3 + 0.7 * Double(total - coversRemaining) / Double(total)
    }

    private var task: Task<Void, Never>?

    private init() {}

    /// Writes the ticked rows, then seeks their covers. A second call while one
    /// runs is ignored.
    func start(csv: String, choices: GoodreadsChoices) {
        guard !isRunning else { return }
        phase = .importing
        outcome = nil
        coversFound = 0
        task = Task {
            do {
                let outcome = try await GoodreadsAPI.importExport(csv: csv, choices: choices)
                self.outcome = outcome
                coversRemaining = outcome.pendingCovers
                await seekCovers()
            } catch {
                phase = .failed(reportError(error))
            }
        }
    }

    /// The cover passes, one after another, until none is left. A failed pass
    /// ends the search without failing the import: the books are in.
    private func seekCovers() async {
        phase = .seekingCovers
        while coversRemaining > 0, !Task.isCancelled {
            do {
                let pass = try await GoodreadsAPI.seekCovers()
                coversFound += pass.found
                coversRemaining = pass.remaining
            } catch {
                _ = reportError(error)
                break
            }
        }
        phase = .finished
    }

    /// Back to idle once the reader has seen how it ended.
    func reset() {
        guard !isRunning else { return }
        phase = .idle
        outcome = nil
    }
}
