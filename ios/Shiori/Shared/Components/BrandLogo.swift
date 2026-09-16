import SwiftUI

/// Branding mark for the login and onboarding screens: a short row of book
/// spines with a bookmark ribbon hanging out of the middle one, cascading in
/// with a one-shot entrance animation (no continuous loop).
///
/// The ribbon is the point — 栞 means bookmark — so it is drawn last, tallest,
/// and in the one saturated colour of the set.
struct BrandLogo: View {
    var spineHeight: CGFloat = 84

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: spineHeight * 0.07) {
            ForEach(Array(Self.spines.enumerated()), id: \.offset) { index, spine in
                BookSpine(
                    color: spine.color,
                    width: spineHeight * spine.width,
                    height: spineHeight * spine.height,
                    hasRibbon: spine.hasRibbon
                )
                .scaleEffect(y: appeared ? 1 : 0.2, anchor: .bottom)
                .opacity(appeared ? 1 : 0)
                .animation(
                    .spring(duration: 0.5, bounce: 0.35).delay(Double(index) * 0.07),
                    value: appeared
                )
            }
        }
        .onAppear { appeared = true }
        .accessibilityElement()
        .accessibilityLabel(Text(verbatim: "Shiori"))
    }

    // Muted paper and cloth tones, so the ribbon is the only thing that shouts.
    private static let linen = Color(red: 0.36, green: 0.42, blue: 0.45)
    private static let ink = Color(red: 0.20, green: 0.25, blue: 0.33)
    private static let clay = Color(red: 0.58, green: 0.40, blue: 0.31)
    private static let sage = Color(red: 0.42, green: 0.49, blue: 0.40)

    private struct Spine {
        let color: Color
        /// Fractions of `spineHeight`, so the mark scales as one piece.
        let width: CGFloat
        let height: CGFloat
        var hasRibbon = false
    }

    private static let spines: [Spine] = [
        Spine(color: linen, width: 0.16, height: 0.82),
        Spine(color: clay, width: 0.13, height: 0.93),
        Spine(color: ink, width: 0.19, height: 1.0, hasRibbon: true),
        Spine(color: sage, width: 0.14, height: 0.88),
        Spine(color: linen, width: 0.12, height: 0.76),
    ]
}

/// One book seen spine-on: a rounded block with a band near each end, the way
/// a hardback's headband and tail read from across a room.
private struct BookSpine: View {
    let color: Color
    let width: CGFloat
    let height: CGFloat
    var hasRibbon = false

    private var cornerRadius: CGFloat { width * 0.22 }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.78)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: width, height: height)
            .overlay(alignment: .top) { band.padding(.top, height * 0.12) }
            .overlay(alignment: .bottom) { band.padding(.bottom, height * 0.12) }
            .overlay(alignment: .top) { if hasRibbon { ribbon } }
            .shadow(color: .black.opacity(0.18), radius: width * 0.12, x: 0, y: width * 0.08)
    }

    private var band: some View {
        Rectangle()
            .fill(.white.opacity(0.22))
            .frame(width: width * 0.62, height: max(1, height * 0.012))
    }

    /// Hangs past the foot of the spine, which is what makes it read as a
    /// bookmark left in the book rather than a stripe printed on it.
    private var ribbon: some View {
        Rectangle()
            .fill(Color.bookmarkRibbon)
            .frame(width: width * 0.26, height: height * 1.12)
            .clipShape(RibbonTail())
            .offset(y: height * 0.04)
    }
}

extension Color {
    /// The one saturated colour of the brand: the bookmark ribbon, shared by
    /// the logo and the loading state so they read as the same object.
    static let bookmarkRibbon = Color(red: 0.78, green: 0.24, blue: 0.27)
}

/// A rectangle with a notch cut out of its bottom edge — the swallowtail end of
/// a ribbon.
private struct RibbonTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - rect.width * 0.55))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

#Preview("Logo") {
    BrandLogo().padding(40)
}

#Preview("Dark") {
    BrandLogo().padding(40).preferredColorScheme(.dark)
}
