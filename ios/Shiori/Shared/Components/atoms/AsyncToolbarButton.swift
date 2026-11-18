import SwiftUI

struct AsyncToolbarButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    var role: ButtonRole? = nil
    /// What the icon does once the call changed it: a heart beats.
    var gesture: IconGesture? = nil
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
            } else if let gesture {
                Label(title, systemImage: systemImage)
                    .iconGesture(gesture, trigger: systemImage)
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
                ToolbarItem(placement: .confirmingAction) {
                    AsyncToolbarButton(title: "Enregistrer", systemImage: "checkmark") {}
                }
            }
    }
}

#Preview("In progress") {
    NavigationStack {
        Text("Contenu")
            .toolbar {
                ToolbarItem(placement: .confirmingAction) {
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
