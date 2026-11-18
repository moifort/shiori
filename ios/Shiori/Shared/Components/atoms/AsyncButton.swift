import SwiftUI

/// A button whose action takes time on the network: it shows a spinner in place
/// of its label from the tap until the call settles, and refuses a second tap
/// meanwhile. Every call to action that waits on a server goes through this or
/// its toolbar sibling, so no tap is ever answered by nothing.
///
/// The label keeps its width while the spinner shows, so a row of buttons does
/// not shuffle when one of them is working.
///
/// An action that says how it went (`ActionOutcome`) is answered too: a
/// success tap once done, the button's own state taking over from there (its
/// label and symbol, drawn by the caller); a shake and an error tap once
/// refused, the label back as it was.
struct AsyncButton<Label: View>: View {
    var role: ButtonRole? = nil
    let action: () async -> ActionOutcome?
    @ViewBuilder let label: () -> Label

    @State private var isInProgress = false
    @State private var successes = 0
    @State private var refusals = 0

    init(
        role: ButtonRole? = nil,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = {
            await action()
            return nil
        }
        self.label = label
    }

    /// A button whose call says whether it went through.
    init(
        role: ButtonRole? = nil,
        outcome: @escaping () async -> ActionOutcome,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = { await outcome() }
        self.label = label
    }

    var body: some View {
        Button(role: role) {
            guard !isInProgress else { return }
            isInProgress = true
            Task {
                let outcome = await action()
                withAnimation(.snappy) { isInProgress = false }
                switch outcome {
                case .done: successes += 1
                case .refused: refusals += 1
                case nil: break
                }
            }
        } label: {
            ZStack {
                label().opacity(isInProgress ? 0 : 1)
                if isInProgress {
                    ProgressView()
                }
            }
        }
        .disabled(isInProgress)
        .refusalShake(trigger: refusals)
        .sensoryFeedback(.success, trigger: successes)
    }
}

extension AsyncButton where Label == Text {
    init(_ title: LocalizedStringKey, role: ButtonRole? = nil, action: @escaping () async -> Void) {
        self.init(role: role, action: action) { Text(title) }
    }
}

extension AsyncButton where Label == SwiftUI.Label<Text, Image> {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () async -> Void
    ) {
        self.init(role: role, action: action) { SwiftUI.Label(title, systemImage: systemImage) }
    }
}

#Preview {
    VStack(spacing: 16) {
        AsyncButton("Réessayer") { try? await Task.sleep(for: .seconds(2)) }
        AsyncButton("Synchroniser", systemImage: "arrow.triangle.2.circlepath") {
            try? await Task.sleep(for: .seconds(2))
        }
        .buttonStyle(.actionPrimary)
        AsyncButton(outcome: {
            try? await Task.sleep(for: .seconds(1))
            return .refused
        }) {
            Label("Ajouter", systemImage: "plus")
        }
        .buttonStyle(.actionGlass)
    }
    .padding()
    .background(.black)
}
