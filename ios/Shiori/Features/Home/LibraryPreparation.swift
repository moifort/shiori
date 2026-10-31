import SwiftUI

/// The moment between the wizard and the first dashboard. Onboarding opens it
/// on its way out; `AuthRoot` keeps the app out of sight and draws
/// `LibraryPreparationView` over the cover wall until it closes, so a reader
/// who linked Audible meets a library with books in it rather than empty cards
/// filling in behind their back.
@MainActor
@Observable
final class LibraryPreparation {
    static let shared = LibraryPreparation()

    private(set) var isActive = false
    /// The libraries onboarding linked, whose passes the checklist waits on.
    private(set) var sources: [ImportSource] = []
    /// Brings the dashboard up to date, and says whether it could: set by the
    /// home tab, already there behind the screen.
    var loadHome: (() async -> Bool)?

    private init() {}

    func begin(linking sources: [ImportSource]) {
        self.sources = sources
        isActive = true
    }

    func finish() {
        withAnimation(.easeInOut(duration: 0.4)) { isActive = false }
    }
}

/// A checklist of what is really being done. Each line ticks
/// off once its work is over: the profile and the welcome scans exist before
/// this screen opens, a library when its pass has landed, the home when the
/// dashboard has loaded.
///
/// Never waits on the passes past `longestWait`: a library of several hundred
/// titles can keep one running for minutes, so its line says it goes on in the
/// background, unticked, and the dashboard's leading spinner takes over.
struct LibraryPreparationView: View {
    @State private var preparation = LibraryPreparation.shared
    @State private var audibleSync = AudibleBackgroundSync.shared
    @State private var kindleSync = KindleBackgroundSync.shared
    /// The step at work: the ones after it are still waiting.
    @State private var current = 0
    /// How the steps over so far ended.
    @State private var outcomes: [Step: PreparationLine.State] = [:]

    private enum Step: Hashable {
        case profile
        case welcomeScans
        case library(ImportSource)
        case home
    }

    /// Long enough to read each tick, even with nothing to wait for.
    private static let pace: Duration = .milliseconds(700)
    private static let longestWait: Duration = .seconds(25)

    var body: some View {
        VStack(spacing: 0) {
            Text("Préparation de votre bibliothèque")
                .font(.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
            PreparationChecklist(lines: lines)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("library-preparation")
        .task { await prepare() }
    }

    private var steps: [Step] {
        [.profile, .welcomeScans] + preparation.sources.map(Step.library) + [.home]
    }

    private var lines: [PreparationLine] {
        steps.enumerated().map { index, step in
            PreparationLine(
                id: String(describing: step),
                label: label(of: step),
                state: outcomes[step] ?? (index == current ? .working : .waiting)
            )
        }
    }

    private func label(of step: Step) -> LocalizedStringKey {
        switch step {
        case .profile: "Votre profil"
        case .welcomeScans: "Vos scans de bienvenue"
        case .library(.audible): "Votre bibliothèque Audible"
        case .library(.kindle): "Votre bibliothèque Kindle"
        case .home: "Votre accueil"
        }
    }

    private func prepare() async {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.longestWait
        for (index, step) in steps.enumerated() {
            current = index
            let outcome = await outcome(of: step, deadline: deadline)
            withAnimation(.snappy) { outcomes[step] = outcome }
            try? await Task.sleep(for: Self.pace)
        }
        guard !Task.isCancelled else { return }
        preparation.finish()
    }

    /// Waits for the step's work and answers how it ended.
    private func outcome(of step: Step, deadline: ContinuousClock.Instant) async -> PreparationLine.State {
        switch step {
        // `completeOnboarding` did both before the wizard moved on.
        case .profile, .welcomeScans:
            return .done
        case .library(.audible):
            return await passOutcome(deadline: deadline, isSyncing: { audibleSync.isSyncing }, error: { audibleSync.errorMessage })
        case .library(.kindle):
            return await passOutcome(deadline: deadline, isSyncing: { kindleSync.isSyncing }, error: { kindleSync.errorMessage })
        case .home:
            return await preparation.loadHome?() == true ? .done : .failed
        }
    }

    private func passOutcome(
        deadline: ContinuousClock.Instant,
        isSyncing: () -> Bool,
        error: () -> String?
    ) async -> PreparationLine.State {
        let clock = ContinuousClock()
        while isSyncing(), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
        if isSyncing() { return .continuing }
        return error() == nil ? .done : .failed
    }
}

#Preview {
    ZStack {
        CoverWall()
        CoverVeil(covering: true)
        LibraryPreparationView()
    }
    .environment(\.colorScheme, .dark)
}
