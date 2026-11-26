import SwiftUI

/// One library's step in the onboarding, in three states. Before any sign-in
/// it says which service it is, what Shiori brings in from it and what it
/// leaves alone, so the reader knows what Amazon's page is for before it
/// opens; then it confirms the connection, or says it failed. Pure.
struct LibraryStepPage: View {
    let library: OnboardingLibrary
    let number: Int
    let count: Int
    var phase: OnboardingLibrarySteps.Phase = .intro
    /// The library the step after this one is for, none on the last.
    var next: OnboardingLibrary?
    /// Amazon's page is being prepared, or the account linked.
    var isWorking = false
    /// Connect (intro), go on (connected), try again (failed).
    var onPrimary: () -> Void
    /// Later (intro), move on without it (failed).
    var onSecondary: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LibraryLogoTile(library: library, isDone: phase == .connected)
                    .padding(.top, 18)

                Text(title)
                    .font(.title.bold())
                    .padding(.top, 16)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                switch phase {
                case .intro:
                    section("Ce que Shiori récupère", library.brings)
                    section("Ce que Shiori ne fait pas", library.leaves)
                    if library == .kindle {
                        Text("Amazon vous redemande de vous connecter, même avec le compte d'Audible.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                    }
                case .connected:
                    LibraryFactList(facts: library.done).padding(.top, 18)
                case .failed:
                    LibraryFactList(facts: [
                        .init(symbol: "lock", title: "Rien n'a été gardé", detail: "Aucune donnée de votre compte n'est restée dans Shiori."),
                    ])
                    .padding(.top, 18)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .top, spacing: 0) {
            OnboardingStepProgress(number: number, count: count)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 12) {
                Button(action: onPrimary) {
                    ZStack {
                        Text(primaryLabel).opacity(isWorking ? 0 : 1)
                        if isWorking { ProgressView() }
                    }
                    .frame(maxWidth: .infinity)
                }
                .disabled(isWorking)
                .buttonStyle(.actionWide)
                .controlSize(.large)
                .tint(.white)
                .foregroundStyle(.black)
                .accessibilityIdentifier("onboarding-library-primary")

                if let secondaryLabel {
                    Button(action: onSecondary) {
                        Text(secondaryLabel).frame(maxWidth: .infinity)
                    }
                    .disabled(isWorking)
                    .buttonStyle(.actionGlass)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding-library-secondary")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var title: LocalizedStringResource {
        switch phase {
        case .intro: library.title
        case .connected: library.doneTitle
        case .failed: library.failedTitle
        }
    }

    private var summary: LocalizedStringResource {
        switch phase {
        case .intro: library.summary
        case .connected: library.doneSummary
        case .failed: "La page d'Amazon n'a pas pu terminer la connexion. Vous pouvez réessayer maintenant, ou plus tard depuis les réglages."
        }
    }

    private var primaryLabel: LocalizedStringResource {
        switch phase {
        case .intro: library.connectLabel
        case .connected: OnboardingLibrary.continueLabel(to: next)
        case .failed: "Réessayer"
        }
    }

    private var secondaryLabel: LocalizedStringResource? {
        switch phase {
        case .intro: "Plus tard"
        case .connected: nil
        case .failed: OnboardingLibrary.skipLabel(to: next)
        }
    }

    private func section(_ header: LocalizedStringResource, _ facts: [OnboardingLibrary.Fact]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(header)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
            LibraryFactList(facts: facts)
        }
        .padding(.top, 18)
    }
}

#Preview("Audible, avant") {
    LibraryStepPage(library: .audible, number: 1, count: 3, next: .kindle, onPrimary: {}, onSecondary: {})
        .environment(\.colorScheme, .dark)
}

#Preview("Kindle, avant") {
    LibraryStepPage(library: .kindle, number: 2, count: 3, next: .goodreads, onPrimary: {}, onSecondary: {})
        .environment(\.colorScheme, .dark)
}

#Preview("Goodreads, avant") {
    LibraryStepPage(library: .goodreads, number: 3, count: 3, onPrimary: {}, onSecondary: {})
        .environment(\.colorScheme, .dark)
}

#Preview("Audible connecté") {
    LibraryStepPage(library: .audible, number: 1, count: 3, phase: .connected, next: .kindle, onPrimary: {}, onSecondary: {})
        .environment(\.colorScheme, .dark)
}

#Preview("Audible, échec") {
    LibraryStepPage(library: .audible, number: 1, count: 3, phase: .failed, next: .kindle, onPrimary: {}, onSecondary: {})
        .environment(\.colorScheme, .dark)
}
