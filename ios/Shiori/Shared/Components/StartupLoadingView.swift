import SwiftUI

/// The launch wait: the bookmark ribbon dropping into place above a short
/// caption, centered in all available space.
///
/// The animation is the app opening, and it is spent here only. Every other
/// wait — a screen loading its content, a list refreshing, a button working —
/// takes the system `ProgressView`, which is what a reader already knows.
struct StartupLoadingView: View {
    var label: LocalizedStringKey = "Chargement..."

    var body: some View {
        VStack(spacing: 20) {
            RibbonMark(motion: .loop, size: 140)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    StartupLoadingView()
}
