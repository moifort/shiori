import SwiftUI

/// A cover's own colours, blurred into the ground of a hero — a book's page, the
/// month's discovery — as the TV app sets a film over its poster. Darkened at
/// the top, where the toolbar's glass sits, and faded into the page at the foot,
/// so the text over it reads in white whatever the cover. Without a cover, a
/// dark neutral ground.
struct CoverBackdrop: View {
    let url: URL?
    /// What the foot fades into: the page the hero opens.
    var ground: Color = Color(.systemGroupedBackground)

    /// How tall the fade into the page is: a hero leaves this much under its
    /// last line.
    static let fadeHeight: CGFloat = 36

    var body: some View {
        // Overlays on a plain ground, so the filled image never grows the
        // backdrop past the frame it is given: it bled under the page.
        Color(white: 0.12)
            .overlay {
                if let url {
                    CoverImage(url: url) {
                        Color.clear
                    } fallback: {
                        Color.clear
                    }
                    .scaleEffect(1.6)
                    .blur(radius: 36, opaque: true)
                    .saturation(1.5)
                    .opacity(0.85)
                }
            }
            .overlay {
                LinearGradient(
                    colors: [.black.opacity(0.45), .black.opacity(0.25), .black.opacity(0.4)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            // Into the page at the very foot only, under the hero's buttons.
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, ground], startPoint: .top, endPoint: .bottom)
                    .frame(height: Self.fadeHeight)
            }
            .clipped()
            // Scaled up for the blur, the image's hit area runs far past the
            // clip: it took the taps of whatever lay under the hero.
            .allowsHitTesting(false)
            // Small and blurred: no need to decode the cover at full size.
            .environment(\.coverMaxPixelSize, 120)
            .accessibilityHidden(true)
    }
}

#Preview {
    CoverBackdrop(url: Book.preview.coverURL)
        .frame(height: 300)
}
