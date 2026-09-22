import SwiftUI

/// The moment between the wizard and the first dashboard. Onboarding opens it
/// on its way out; the Home tab draws `LibraryPreparationView` instead of the
/// dashboard until it closes, so a reader who linked Audible meets a library
/// with books in it rather than empty cards filling in behind their back.
@MainActor
@Observable
final class LibraryPreparation {
    static let shared = LibraryPreparation()

    private(set) var isActive = false

    private init() {}

    func begin() {
        isActive = true
    }

    func finish() {
        withAnimation(.easeInOut(duration: 0.4)) { isActive = false }
    }
}

/// The ribbon over a caption that says what is being done: the library being
/// prepared, and Audible being read while its pass runs.
///
/// Held long enough to read even with nothing to wait for, and never longer
/// than `longestWait`: a library of several hundred titles can keep the pass
/// running for minutes, and past that point the dashboard's leading spinner
/// says the rest is on its way.
struct LibraryPreparationView: View {
    /// Loads the dashboard the view gives way to, once the pass has landed.
    let onReady: () async -> Void

    @State private var audibleSync = AudibleBackgroundSync.shared

    private static let shortestWait: Duration = .seconds(2)
    private static let longestWait: Duration = .seconds(25)

    var body: some View {
        VStack(spacing: 20) {
            RibbonMark(motion: .loop, size: 140)
            VStack(spacing: 6) {
                Text("Préparation de votre bibliothèque")
                    .font(.headline)
                Group {
                    if audibleSync.isSyncing {
                        Text("Synchronisation avec Audible…")
                    } else {
                        Text("Presque prêt…")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .animation(.easeInOut, value: audibleSync.isSyncing)
            }
            .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("library-preparation")
        .task { await prepare() }
    }

    private func prepare() async {
        let clock = ContinuousClock()
        let deadline = clock.now + Self.longestWait
        try? await Task.sleep(for: Self.shortestWait)
        while audibleSync.isSyncing, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
        guard !Task.isCancelled else { return }
        await onReady()
        LibraryPreparation.shared.finish()
    }
}

#Preview {
    LibraryPreparationView(onReady: {})
}
