import SwiftUI

struct ViewfinderOverlay: View {
    /// Whether the shutter sits over the viewfinder, below the frame. On an
    /// unfolded iPhone Duo it has a page of its own, and the frame takes the
    /// height.
    var leavesRoomForShutter = true

    var body: some View {
        GeometryReader { geo in
            // Shaped like a cover (2:3) and as large as the screen allows, while
            // leaving the shutter below it uncovered.
            let height = min(
                geo.size.width * 0.88 * 1.5,
                geo.size.height * (leavesRoomForShutter ? 0.64 : 0.84)
            )
            let width = height / 1.5
            let x = (geo.size.width - width) / 2
            let y = (geo.size.height - height) / 2

            let cutoutRect = CGRect(x: x, y: y, width: width, height: height)

            Canvas { context, size in
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.4))
                )
                context.blendMode = .clear
                context.fill(
                    Path(roundedRect: cutoutRect, cornerRadius: 20),
                    with: .color(.white)
                )
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 20)
                .stroke(.white.opacity(0.8), lineWidth: 3)
                .frame(width: width, height: height)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ZStack {
        Color.gray
        ViewfinderOverlay()
    }
}
