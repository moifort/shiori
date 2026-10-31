import SwiftUI

/// The launch curtain's drifting covers, kept going behind the sign-in and the
/// onboarding: the app opens onto them and the reader stays with them until the
/// library is ready. What stands in front brings its own `CoverVeil`.
struct CoverWall: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Decoded off the main thread, then faded in: empty until they are ready.
    @State private var covers: [CGImage] = []

    var body: some View {
        ZStack {
            Color.black
            CoverDrift(covers: covers, moving: !reduceMotion)
                .opacity(covers.isEmpty ? 0 : 1)
                .animation(.easeOut(duration: 0.8), value: covers.isEmpty)
        }
        .ignoresSafeArea()
        .task {
            covers = await Task.detached(priority: .userInitiated) { LaunchCurtain.loadCovers() }.value
        }
        .accessibilityHidden(true)
    }
}

/// The blur text stands on over a `CoverWall`: rising from the bottom, leaving
/// the covers sharp above, or `covering` the whole screen. Animate `covering`
/// and it climbs up over them.
struct CoverVeil: View {
    var covering = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .mask {
                    LinearGradient(
                        stops: [.init(color: .clear, location: 0.46), .init(color: .black, location: 0.64)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            Rectangle()
                .fill(.regularMaterial)
                .opacity(covering ? 1 : 0)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The wait while getting in: the ribbon, and a capsule saying what is going on.
struct OpeningProgress: View {
    var label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 30) {
            RibbonMark(motion: .loop, size: 84)
            HStack(spacing: 10) {
                ProgressView()
                Text(label)
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .glassEffect(.regular, in: .capsule)
        }
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        CoverWall()
        CoverVeil(covering: true)
        OpeningProgress(label: "Connexion en cours…")
    }
    .environment(\.colorScheme, .dark)
}
