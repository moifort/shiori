import SwiftUI

/// One line of the checklist: a piece of work and how far it has got.
struct PreparationLine: Identifiable {
    enum State: Equatable {
        case waiting
        case working
        case done
        /// Still running, past what the screen waits for: no tick.
        case continuing
        case failed
    }

    let id: String
    let label: LocalizedStringKey
    let state: State
}

/// The todo list of the moment before the first dashboard, each line ticking
/// off when its work is really over.
struct PreparationChecklist: View {
    let lines: [PreparationLine]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.element.id) { index, line in
                if index > 0 { Divider() }
                row(line)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }

    private func row(_ line: PreparationLine) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            mark(line.state)
                .frame(width: 22, height: 22)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
            VStack(alignment: .leading, spacing: 2) {
                Text(line.label)
                    .font(.body.weight(.semibold))
                    .opacity(line.state == .waiting ? 0.4 : 1)
                if let note = note(line.state) {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func mark(_ state: PreparationLine.State) -> some View {
        switch state {
        case .waiting:
            Image(systemName: "circle")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
        case .working:
            ProgressView()
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.black, .white)
                .transition(.symbolEffect(.drawOn))
                .accessibilityLabel("Terminé")
        case .continuing:
            Image(systemName: "clock")
                .font(.system(size: 20))
        case .failed:
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 20))
                .accessibilityLabel("Échec")
        }
    }

    private func note(_ state: PreparationLine.State) -> LocalizedStringKey? {
        switch state {
        case .continuing: "Se poursuit en arrière-plan"
        case .failed: "Vous pourrez réessayer depuis les réglages"
        case .waiting, .working, .done: nil
        }
    }
}

#Preview {
    ZStack {
        CoverWall()
        CoverVeil(covering: true)
        PreparationChecklist(lines: [
            PreparationLine(id: "profile", label: "Votre profil", state: .done),
            PreparationLine(id: "scans", label: "Vos scans de bienvenue", state: .done),
            PreparationLine(id: "audible", label: "Votre bibliothèque Audible", state: .continuing),
            PreparationLine(id: "kindle", label: "Votre bibliothèque Kindle", state: .failed),
            PreparationLine(id: "home", label: "Votre accueil", state: .working),
        ])
        .padding(.horizontal, 20)
    }
    .environment(\.colorScheme, .dark)
}
