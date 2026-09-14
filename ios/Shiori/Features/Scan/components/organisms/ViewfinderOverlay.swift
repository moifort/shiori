import SwiftUI

struct ViewfinderOverlay: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width * 0.8
            let height = geo.size.height * 0.45
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
