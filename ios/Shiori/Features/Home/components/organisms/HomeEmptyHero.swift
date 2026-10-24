import SwiftUI

/// The top of a phone's home screen before the first book, in the carousel's
/// grammar: where a cover would stand, a stack of blank covers with a camera on
/// the front one, over warm colours of its own; under it what to do, in one
/// line, and the one button that does it. The figures head it as they head
/// the carousel, so the page keeps its shape from the first day.
struct HomeEmptyHero: View {
    let onScan: () -> Void

    /// How tall the fade into the page is: as the carousel's, so the rows
    /// start the same way under either.
    private static let fadeHeight: CGFloat = 240

    var body: some View {
        VStack(spacing: 0) {
            stack
                .padding(.top, 26)
            Text("Votre bibliothèque commence ici")
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 24)
            Text("Une photo de la couverture suffit")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 4)
            Button(action: onScan) {
                Label("Scanner un livre", systemImage: "camera")
                    .font(.headline)
                    .frame(width: 200)
            }
            .buttonStyle(.glassProminent)
            .tint(.white)
            .foregroundStyle(.black)
            .controlSize(.extraLarge)
            .padding(.top, 20)
            .accessibilityIdentifier("home-scan")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .padding(.bottom, 40)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, .dark)
        .background {
            ground
                // Up under the bars and the status bar, as the carousel's
                // backdrops run.
                .padding(.top, -400)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-empty")
    }

    /// Three blank covers fanned out, the front one carrying the camera: the
    /// shelf to come, and the way onto it.
    private var stack: some View {
        ZStack {
            cover.rotationEffect(.degrees(-7)).offset(x: -14, y: 4)
            cover.rotationEffect(.degrees(6)).offset(x: 14, y: 6)
            cover
                .overlay {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .shadow(color: .black.opacity(0.45), radius: 18, y: 12)
        }
        .frame(width: 150, height: 188)
        .accessibilityHidden(true)
    }

    private var cover: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [.white.opacity(0.18), .white.opacity(0.06)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
            .frame(width: 122, height: 180)
    }

    /// Warm colours where a cover's would blur, darkened at the top under the
    /// bar and faded into the page at the foot along the carousel's curve.
    private var ground: some View {
        ZStack {
            RadialGradient(
                colors: [Color(red: 0.42, green: 0.16, blue: 0.11), Color(red: 0.23, green: 0.11, blue: 0.16), Color(red: 0.05, green: 0.07, blue: 0.09)],
                center: UnitPoint(x: 0.3, y: 0.15),
                startRadius: 0,
                endRadius: 520
            )
            LinearGradient(
                colors: [.black.opacity(0.45), .black.opacity(0.1), .black.opacity(0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: (0...12).map { step in
                    let t = Double(step) / 12
                    return .init(color: Color(.systemGroupedBackground).opacity(t * t * (3 - 2 * t)), location: t)
                },
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Self.fadeHeight)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        HomeEmptyHero {}
    }
    .background(Color(.systemGroupedBackground))
}
