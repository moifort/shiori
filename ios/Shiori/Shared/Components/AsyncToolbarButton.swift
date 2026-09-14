import SwiftUI

struct AsyncToolbarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    let action: () async -> Void

    @State private var isInProgress = false

    var body: some View {
        Button(role: role) {
            guard !isInProgress else { return }
            isInProgress = true
            Task {
                await action()
                isInProgress = false
            }
        } label: {
            if isInProgress {
                ProgressView()
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .labelStyle(.iconOnly)
        .disabled(isInProgress)
    }
}

#Preview("Idle") {
    NavigationStack {
        Text("Contenu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {}
                }
            }
    }
}

#Preview("In progress") {
    NavigationStack {
        Text("Contenu")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // A long action keeps the spinner on screen in the canvas.
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {
                        try? await Task.sleep(for: .seconds(60))
                    }
                }
            }
    }
}

#Preview("Destructive") {
    NavigationStack {
        Text("Contenu")
            .toolbar {
                ToolbarItem(placement: .destructiveAction) {
                    AsyncToolbarButton(
                        title: "Supprimer",
                        systemImage: "trash",
                        role: .destructive
                    ) {}
                }
            }
    }
}
