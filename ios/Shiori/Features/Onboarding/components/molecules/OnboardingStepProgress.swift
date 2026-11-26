import SwiftUI

/// "Étape 1 sur 3" over one segment per library the reader ticked, the ones
/// reached filled: where the reader stands among the connections.
struct OnboardingStepProgress: View {
    let number: Int
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(1...max(count, 1), id: \.self) { step in
                    Capsule()
                        .fill(step <= number ? Color.white : Color(.tertiarySystemFill))
                        .frame(height: 4)
                }
            }
            Text("Étape \(number) sur \(count)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Étape \(number) sur \(count)"))
    }
}

#Preview {
    VStack(spacing: 24) {
        OnboardingStepProgress(number: 1, count: 3)
        OnboardingStepProgress(number: 2, count: 3)
        OnboardingStepProgress(number: 1, count: 1)
    }
    .padding()
    .environment(\.colorScheme, .dark)
}
