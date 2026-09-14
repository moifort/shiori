import SwiftUI

/// The wizard shown once, before the library exists. Two steps, not Vinarium's
/// five: there is no cellar to size, so all it collects is a first name.
///
/// It is kept as a wizard rather than a single field because of what completing
/// it does — it grants the welcome scans — and because the welcome step is the
/// one place to say what the app is for before asking for anything.
struct OnboardingView: View {
    var onCompleted: () -> Void

    @State private var step: Step = .welcome
    @State private var firstName = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private enum Step {
        case welcome
        case firstName
    }

    var body: some View {
        Group {
            switch step {
            case .welcome:
                WelcomePage(onNext: { withAnimation { step = .firstName } })
            case .firstName:
                FirstNamePage(
                    firstName: $firstName,
                    onNext: { Task { await complete() } },
                    onBack: { withAnimation { step = .welcome } }
                )
            }
        }
        .disabled(isSaving)
        .overlay { if isSaving { ProgressView().controlSize(.large) } }
        .alert(
            "Impossible de terminer",
            isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear { track(.onboardingStarted) }
    }

    private func complete() async {
        let name = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await OnboardingAPI.completeOnboarding(firstName: name)
            track(.onboardingCompleted)
            onCompleted()
        } catch {
            // Stays on the step rather than dropping the reader into an empty
            // app: the welcome scans are granted by this call, and letting it
            // fail silently would cost them 50 scans they never learn about.
            errorMessage = ErrorPresenter.message(for: error)
        }
    }
}

#Preview {
    OnboardingView(onCompleted: {})
}
