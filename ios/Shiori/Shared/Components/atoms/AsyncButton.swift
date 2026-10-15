import SwiftUI

/// A button whose action takes time on the network: it shows a spinner in place
/// of its label from the tap until the call settles, and refuses a second tap
/// meanwhile. Every call to action that waits on a server goes through this or
/// its toolbar sibling, so no tap is ever answered by nothing.
///
/// The label keeps its width while the spinner shows, so a row of buttons does
/// not shuffle when one of them is working.
struct AsyncButton<Label: View>: View {
    var role: ButtonRole? = nil
    let action: () async -> Void
    @ViewBuilder let label: () -> Label

    @State private var isInProgress = false

    init(
        role: ButtonRole? = nil,
        action: @escaping () async -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.role = role
        self.action = action
        self.label = label
    }

    var body: some View {
        Button(role: role) {
            guard !isInProgress else { return }
            isInProgress = true
            Task {
                await action()
                isInProgress = false
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
        .buttonStyle(.borderedProminent)
    }
    .padding()
}
