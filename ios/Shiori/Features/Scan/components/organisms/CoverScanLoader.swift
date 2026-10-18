import SwiftUI

/// The captured cover being read: the photo framed like a book, four viewfinder
/// corners around it, and the `ScanBeam` sweeping the page top to bottom and
/// back.
///
/// Showing the reader's own shot is the point. A scan is a long wait, and a
/// picture of *their* cover under the beam says what is being worked on far
/// better than an abstract spinner would. Without a photo (previews, a decode
/// failure) a closed-book placeholder takes the beam instead.
///
/// The beam is `ScanBeam`, the one every AI reading of a photo wears. Purely
/// presentational.
struct CoverScanLoader: View {
    var cover: UIImage?
    /// Width of the cover in points; the height follows a paperback's proportions.
    var width: CGFloat = 168

    private let cornerRadius: CGFloat = 12
    /// How far the corners sit outside the cover.
    private let bracketInset: CGFloat = 12

    private var height: CGFloat { width * 1.45 }

    var body: some View {
        coverFace
            .frame(width: width, height: height)
            .overlay { ScanBeam() }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
            .padding(bracketInset)
            .overlay {
                ViewfinderCorners(length: 22)
                    .stroke(
                        Color.primary.opacity(0.75),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                    )
            }
            .accessibilityHidden(true)
    }

    // MARK: - Cover

    @ViewBuilder
    private var coverFace: some View {
        if let cover {
            Image(uiImage: cover)
                .resizable()
                .scaledToFill()
                .frame(width: width, height: height)
                .overlay(spineShade)
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "book.closed")
                        .font(.system(size: width * 0.38, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .overlay(spineShade)
        }
    }

    /// A shadow down the left edge, where a cover bends into its spine. It is
    /// what turns a rectangle of pixels into a book.
    private var spineShade: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.28), location: 0),
                .init(color: .black.opacity(0.06), location: 0.035),
                .init(color: .clear, location: 0.09),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

}

/// Four L-shaped strokes in the corners of a rect, the way a camera marks
/// what it is focusing on.
private struct ViewfinderCorners: Shape {
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners: [(CGPoint, CGFloat, CGFloat)] = [
            (CGPoint(x: rect.minX, y: rect.minY), 1, 1),
            (CGPoint(x: rect.maxX, y: rect.minY), -1, 1),
            (CGPoint(x: rect.maxX, y: rect.maxY), -1, -1),
            (CGPoint(x: rect.minX, y: rect.maxY), 1, -1),
        ]
        for (corner, dx, dy) in corners {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}

#Preview("Placeholder") {
    CoverScanLoader()
}

#Preview("Dark") {
    CoverScanLoader().preferredColorScheme(.dark)
}
