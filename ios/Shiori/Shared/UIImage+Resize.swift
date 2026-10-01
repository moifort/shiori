import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let maxSide = max(size.width, size.height)
        if maxSide <= maxDimension { return self }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize, format: .pixelExact)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

extension UIGraphicsImageRendererFormat {
    /// One pixel per point, eight bits per channel. The default format draws
    /// at the screen's scale and, on a wide-colour photo, in sixteen-bit
    /// floats: a "2000 px" shelf photo came out 6000 px wide, and each spine
    /// cut from it weighed tens of megabytes, until the watchdog killed the app.
    static var pixelExact: UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.preferredRange = .standard
        return format
    }
}
