import SwiftUI

/// The bookmark — 栞, shiori — hanging from the top edge of a book being read:
/// a white ribbon with a notched tail, slipped into the open book. Says the
/// book is open at a glance and claims no position.
struct BookmarkRibbon: View {
    var width: CGFloat = 14

    var body: some View {
        NotchedRibbon()
            .fill(
                LinearGradient(
                    colors: [Color(white: 0.85), .white, Color(white: 0.81)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: width * 2.15)
            .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
            .accessibilityHidden(true)
    }
}

/// A ribbon's outline: a strip whose foot is cut in a V.
private struct NotchedRibbon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notch = rect.width * 0.45
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - notch))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HStack(spacing: 20) {
        BookmarkRibbon()
        BookmarkRibbon(width: 12)
    }
    .padding()
    .background(.black)
}
