import SwiftUI

/// A burst of confetti from one point, once: the pieces fly out, turn, fall
/// and fade within two seconds, then nothing is drawn. It catches no touch.
///
/// One `Canvas` draws every piece at a given moment of the burst, and the
/// moment is animated: SwiftUI hands the canvas each value between start and
/// end, so sixty pieces cost one redraw a frame rather than sixty views.
struct ConfettiBurst: View {
    /// How far the pieces fly, in points from the centre.
    var reach: CGFloat = 170
    var count: Int = 64

    /// From 0 as the burst starts to 1 once every piece has faded.
    @State private var progress: Double = 0
    @State private var pieces: [Piece] = []

    fileprivate static let duration: Double = 2.2
    private static let colors: [Color] = [
        .orange, .green, .blue, .pink, .yellow, .purple, .cyan, .white,
    ]

    var body: some View {
        BurstFrame(pieces: pieces, progress: progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                pieces = (0..<count).map { _ in Piece.random(reach: reach, colors: Self.colors) }
                withAnimation(.linear(duration: Self.duration)) { progress = 1 }
            }
    }
}

/// One moment of the burst. Animatable, so the canvas redraws at every value
/// of the progress the animation passes through.
private struct BurstFrame: View, Animatable {
    let pieces: [Piece]
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        Canvas { context, size in
            guard progress > 0, progress < 1 else { return }
            let elapsed = CGFloat(progress * ConfettiBurst.duration)
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            for piece in pieces {
                draw(piece, at: elapsed, from: centre, in: context)
            }
        }
    }

    private func draw(_ piece: Piece, at t: CGFloat, from centre: CGPoint, in context: GraphicsContext) {
        // Thrown out fast, slowed by the air, pulled down by gravity.
        let drag = (1 - exp(-3.2 * t)) / 3.2
        let x = centre.x + piece.velocity.dx * drag
        let y = centre.y + piece.velocity.dy * drag + 140 * t * t
        var context = context
        context.opacity = max(0, 1 - max(0, t - 1.1) / 1.1)
        context.translateBy(x: x, y: y)
        context.rotate(by: .degrees(piece.spin * Double(t) + piece.angle))
        // A strip flips as it turns: its width breathes with the spin.
        let flip = abs(cos(Double(t) * piece.flutter + piece.angle))
        let rect = CGRect(
            x: -piece.size.width / 2 * flip, y: -piece.size.height / 2,
            width: piece.size.width * flip, height: piece.size.height
        )
        let shape = piece.isRound
            ? Path(ellipseIn: rect)
            : Path(roundedRect: rect, cornerRadius: 1)
        context.fill(shape, with: .color(piece.color))
    }
}

/// One piece of confetti: where it is thrown, and how it looks and turns.
private struct Piece {
    let velocity: CGVector
    let size: CGSize
    let color: Color
    let isRound: Bool
    let angle: Double
    let spin: Double
    let flutter: Double

    static func random(reach: CGFloat, colors: [Color]) -> Piece {
        let direction = Double.random(in: 0..<(2 * .pi))
        let speed = CGFloat.random(in: 0.45...1) * reach * 3.2
        let isRound = Bool.random() && Bool.random()
        let side = CGFloat.random(in: 5...7)
        return Piece(
            // A little more up than down, so the burst rises before it falls.
            velocity: CGVector(dx: cos(direction) * speed, dy: sin(direction) * speed - reach * 0.9),
            size: isRound
                ? CGSize(width: side, height: side)
                : CGSize(width: .random(in: 4...6), height: .random(in: 9...13)),
            color: colors.randomElement() ?? .white,
            isRound: isRound,
            angle: .random(in: 0..<180),
            spin: .random(in: -540...540),
            flutter: .random(in: 4...10)
        )
    }
}

#Preview {
    ZStack {
        Color.black
        Circle().fill(.gray).frame(width: 62, height: 62)
        ConfettiBurst()
    }
}
