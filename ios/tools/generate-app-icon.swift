// Renders the app icon from the brand mark: `ShioriMark`'s ribbon on its cream
// field, 1024 × 1024, opaque sRGB, the way the App Store wants it. Writes
// `AppIcon.png` and its `Contents.json` into the given `.appiconset`, so the
// icon is produced from the same geometry the app animates on its start.
//
//   swiftc -o /tmp/generate-app-icon \
//     ios/tools/generate-app-icon.swift ios/Shiori/Shared/Components/ShioriMark.swift \
//     && /tmp/generate-app-icon ios/Shiori/Assets.xcassets/AppIcon.appiconset
//
import AppKit
import UniformTypeIdentifiers

@main
struct GenerateAppIcon {
    static func main() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 2 else {
            FileHandle.standardError.write(Data("usage: generate-app-icon <AppIcon.appiconset>\n".utf8))
            exit(64)
        }
        let target = URL(fileURLWithPath: arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)

        let image = render()
        try write(image, to: target.appendingPathComponent("AppIcon.png"))
        try contentsJSON.write(
            to: target.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8
        )
        print("wrote \(target.path)/AppIcon.png")
    }

    /// The mark's canvas, painted top down like the app does.
    static func render() -> CGImage {
        let side = Int(ShioriMark.canvas)
        let ctx = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        // CoreGraphics puts the origin at the bottom; the mark is drawn y down.
        ctx.translateBy(x: 0, y: ShioriMark.canvas)
        ctx.scaleBy(x: 1, y: -1)

        ctx.setFillColor(color(ShioriMark.fieldColor))
        ctx.fill(CGRect(x: 0, y: 0, width: ShioriMark.canvas, height: ShioriMark.canvas))
        ctx.setFillColor(color(ShioriMark.ribbonColor))
        ctx.addPath(ShioriMark.ribbon())
        ctx.fillPath()
        ctx.setFillColor(color(ShioriMark.foldColor))
        ctx.addPath(ShioriMark.fold())
        ctx.fillPath()
        return ctx.makeImage()!
    }

    static func color(_ rgb: ShioriMark.RGB) -> CGColor {
        CGColor(
            colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            components: [rgb.red, rgb.green, rgb.blue, 1]
        )!
    }

    static func write(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    static let contentsJSON = """
    {
      "images" : [
        {
          "filename" : "AppIcon.png",
          "idiom" : "universal",
          "platform" : "ios",
          "size" : "1024x1024"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }

    """
}
