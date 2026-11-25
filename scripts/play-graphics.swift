// Draws the Google Play store graphics from the iOS app icon: the 512 px icon and the
// 1024 x 500 feature graphic (the icon on its own midnight blue, the name and a tagline).
//
//   swift scripts/play-graphics.swift ios/Shiori/Assets.xcassets/AppIcon.appiconset/AppIcon.png infra/play/graphics
import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3, let icon = NSImage(contentsOfFile: arguments[1]) else {
  print("usage: play-graphics.swift <AppIcon.png> <output folder>")
  exit(1)
}
let output = URL(fileURLWithPath: arguments[2])

func render(width: Int, height: Int, draw: (CGContext) -> Void) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  draw(NSGraphicsContext.current!.cgContext)
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

let iconImage = icon.cgImage(forProposedRect: nil, context: nil, hints: nil)!

// The icon's own background, read from its bottom corner, the darkest of its gradient.
let corner = NSBitmapImageRep(cgImage: iconImage).colorAt(x: 4, y: 1019)!

let iconData = render(width: 512, height: 512) { context in
  context.interpolationQuality = .high
  context.draw(iconImage, in: CGRect(x: 0, y: 0, width: 512, height: 512))
}
try iconData.write(to: output.appendingPathComponent("icon-512.png"))

for (language, tagline) in [
  ("fr-FR", "Scannez et suivez vos lectures"), ("en-US", "Scan and track your reading"),
] {
  let banner = render(width: 1024, height: 500) { context in
    context.setFillColor(corner.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: 1024, height: 500))
    context.interpolationQuality = .high
    // The icon as a launcher draws it: a rounded tile, lifted off the blue by a soft shadow.
    let tile = CGRect(x: 90, y: 90, width: 320, height: 320)
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: -10), blur: 40,
      color: NSColor.black.withAlphaComponent(0.45).cgColor)
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 72, cornerHeight: 72, transform: nil))
    context.setFillColor(corner.cgColor)
    context.fillPath()
    context.restoreGState()
    context.saveGState()
    context.addPath(CGPath(roundedRect: tile, cornerWidth: 72, cornerHeight: 72, transform: nil))
    context.clip()
    context.draw(iconImage, in: tile)
    context.restoreGState()
    let name = NSAttributedString(
      string: "Shiori",
      attributes: [
        .font: NSFont.systemFont(ofSize: 112, weight: .bold), .foregroundColor: NSColor.white,
      ])
    name.draw(at: NSPoint(x: 470, y: 238))
    let line = NSAttributedString(
      string: tagline,
      attributes: [
        .font: NSFont.systemFont(ofSize: 36, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.8),
      ])
    line.draw(at: NSPoint(x: 476, y: 180))
  }
  try banner.write(to: output.appendingPathComponent("feature-graphic-\(language).png"))
}
print("written to \(output.path)")
