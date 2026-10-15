import CoreGraphics

/// The brand's one mark: a bookmark ribbon hanging from the top edge, its
/// swallowtail cut into the bottom, a darker band at the top where it folds
/// over the page. Shiori (栞) means bookmark, and this is the whole logo.
///
/// The mark is laid out on a 1024-unit square, y down, which is also the app
/// icon: the ribbon on a cream field. Pure CoreGraphics on purpose, so the same
/// file compiles into the app (where `RibbonMark` animates it) and into
/// `ios/tools/generate-app-icon.swift` (which rasterises it). One geometry,
/// one set of colours, and the icon cannot drift from the animation.
enum ShioriMark {
    /// Side of the square the mark is designed on. The icon is this square.
    static let canvas: CGFloat = 1024

    static let ribbonWidth: CGFloat = 160
    /// From the top edge down to the two points of the swallowtail.
    static let ribbonLength: CGFloat = 880
    /// How far the swallowtail cuts up into the ribbon.
    static let notchDepth: CGFloat = 80
    /// The band at the top that reads as the ribbon folding over the page edge.
    static let foldHeight: CGFloat = 70

    /// The ribbon's box on the canvas, centred, hanging from the top.
    static let ribbonRect = CGRect(
        x: (canvas - ribbonWidth) / 2, y: 0, width: ribbonWidth, height: ribbonLength
    )

    /// Where the ribbon is held: the middle of its top edge. Any swing pivots here.
    static let pivot = CGPoint(x: canvas / 2, y: 0)

    /// The ribbon with its swallowtail, in canvas coordinates.
    static func ribbon() -> CGPath {
        let r = ribbonRect
        let path = CGMutablePath()
        path.move(to: CGPoint(x: r.minX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        path.addLine(to: CGPoint(x: r.midX, y: r.maxY - notchDepth))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        path.closeSubpath()
        return path
    }

    /// The fold band across the top of the ribbon, in canvas coordinates.
    static func fold() -> CGPath {
        CGPath(
            rect: CGRect(x: ribbonRect.minX, y: 0, width: ribbonWidth, height: foldHeight),
            transform: nil
        )
    }

    /// A colour as sRGB components, so both SwiftUI and CoreGraphics can build
    /// their own from it.
    struct RGB {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// The one saturated colour of the brand.
    static let ribbonColor = RGB(red: 0.78, green: 0.24, blue: 0.27)
    static let foldColor = RGB(red: 0.66, green: 0.19, blue: 0.23)
    /// The icon's field: the cream of a page.
    static let fieldColor = RGB(red: 0.96, green: 0.93, blue: 0.86)
}
