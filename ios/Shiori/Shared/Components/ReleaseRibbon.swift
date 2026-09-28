import SwiftUI

/// The message on top of a book's page — where a release stands, a book
/// already held — drawn as the app's icon draws its bookmark, laid on its
/// side: a ribbon that comes out of the page's leading edge — the darker band
/// where it is tucked in — and ends in the icon's notch, the words in white on
/// the message's colour. Every page's top message wears it, a touch of the
/// icon across the app.
struct ReleaseRibbon: View {
    let text: String
    let systemImage: String
    let tint: Color

    private let height: CGFloat = 40
    /// The tucked-in band, as the icon's darker top.
    private let band: CGFloat = 8
    /// The notch cut into its end, half the ribbon's height deep as the icon's is.
    private var notch: CGFloat { height / 2 }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.white)
        .lineLimit(1)
        .padding(.leading, band + 12)
        .padding(.trailing, notch + 14)
        .frame(height: height)
        .background {
            ZStack(alignment: .leading) {
                Rectangle().fill(tint)
                Rectangle().fill(.black.opacity(0.18)).frame(width: band)
            }
            .clipShape(BookmarkRibbonShape(notch: notch))
        }
        .accessibilityElement(children: .combine)
    }
}

/// A band cut with a notch at its trailing end.
private struct BookmarkRibbonShape: Shape {
    let notch: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

extension View {
    /// Lays a ribbon in a list as the header of an empty section — a row would
    /// be clipped to the section's rounded corners — flush with the leading
    /// edge of the sections under it.
    func ribbonRow() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 16)
            .textCase(nil)
            .listRowInsets(EdgeInsets())
    }
}
