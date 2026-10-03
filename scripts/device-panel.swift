// Draws an iPhone 17 Pro Max around a capture, on a plain backdrop or a
// photograph, for the panels that show the app alone.
//
// Drawn rather than generated: the image model's phones are never the real
// proportions, and a capture fitted onto one either squeezes or leaves a strip
// along the glass. Drawn to the device's own geometry, the capture fills the
// screen to the pixel. The caption is set afterwards (finish-panel.swift).
//
// Usage: swift device-panel.swift <#RRGGBB | backdrop.jpg> <capture.png> <out.png>

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func load(_ path: String) -> CGImage {
  guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else { fail("cannot read \(path)") }
  return image
}

let arguments = CommandLine.arguments
guard arguments.count == 4 else {
  fail("usage: device-panel.swift <#RRGGBB | backdrop.jpg> <capture.png> <out.png>")
}
let (backdrop, capturePath, outputPath) = (arguments[1], arguments[2], arguments[3])

let width = 1320, height = 2868
guard
  let context = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fail("cannot allocate the panel") }
context.interpolationQuality = .high

// The backdrop: a flat colour, or a photograph scaled to cover the panel.
if backdrop.hasPrefix("#"), let hex = Int(backdrop.dropFirst(), radix: 16) {
  context.setFillColor(
    CGColor(
      red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255,
      blue: Double(hex & 255) / 255, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: width, height: height))
} else {
  let image = load(backdrop)
  let scale = max(Double(width) / Double(image.width), Double(height) / Double(image.height))
  let size = CGSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
  context.draw(
    image,
    in: CGRect(
      x: (Double(width) - size.width) / 2, y: (Double(height) - size.height) / 2,
      width: size.width, height: size.height))
}

// The device, in the iPhone 17 Pro Max's own proportions: a 440x956-point
// display, a black border a little under 2% of its width, a titanium band
// around it, the Dynamic Island 126x37 points, 11 points from the top. The
// screen takes three quarters of the panel's height, under the caption band.
let screenHeight = Double(height) * 0.75
let point = screenHeight / 956
let screenWidth = 440 * point
let screen = CGRect(
  x: (Double(width) - screenWidth) / 2,
  y: Double(height) * 0.055,
  width: screenWidth, height: screenHeight)
let border = 7 * point
let band = 4.5 * point
let screenRadius = 55 * point
let glass = screen.insetBy(dx: -border, dy: -border)
let body = glass.insetBy(dx: -band, dy: -band)

func rounded(_ rect: CGRect, _ radius: Double) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// A soft shadow under the device, as on a table under daylight.
context.saveGState()
context.setShadow(
  offset: CGSize(width: 0, height: -band * 6), blur: band * 22,
  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.28))
context.addPath(rounded(body, screenRadius + border + band))
context.setFillColor(CGColor(red: 0.62, green: 0.6, blue: 0.57, alpha: 1))
context.fillPath()
context.restoreGState()

// The side buttons, standing a little proud of the band: the action button and
// the volume on the left, the side button and Camera Control on the right.
context.setFillColor(CGColor(red: 0.56, green: 0.54, blue: 0.51, alpha: 1))
let buttonDepth = band * 0.9
for (top, length) in [(140.0, 34.0), (200.0, 62.0), (275.0, 62.0)] {
  context.addPath(
    rounded(
      CGRect(
        x: body.minX - buttonDepth, y: body.maxY - (top + length) * point,
        width: buttonDepth * 2, height: length * point), buttonDepth))
}
for (top, length) in [(220.0, 98.0), (560.0, 70.0)] {
  context.addPath(
    rounded(
      CGRect(
        x: body.maxX - buttonDepth, y: body.maxY - (top + length) * point,
        width: buttonDepth * 2, height: length * point), buttonDepth))
}
context.fillPath()

// The titanium band, lit from the upper left: brushed metal reads as a
// gradient, a flat grey as a cardboard cut-out.
context.saveGState()
context.addPath(rounded(body, screenRadius + border + band))
context.clip()
if let gradient = CGGradient(
  colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
  colors: [
    CGColor(red: 0.86, green: 0.84, blue: 0.81, alpha: 1),
    CGColor(red: 0.6, green: 0.58, blue: 0.55, alpha: 1),
    CGColor(red: 0.78, green: 0.76, blue: 0.73, alpha: 1),
    CGColor(red: 0.52, green: 0.5, blue: 0.47, alpha: 1),
  ] as CFArray,
  locations: [0, 0.35, 0.7, 1])
{
  context.drawLinearGradient(
    gradient, start: CGPoint(x: body.minX, y: body.maxY),
    end: CGPoint(x: body.maxX, y: body.minY), options: [])
}
context.restoreGState()

// The black border, then the capture clipped to the screen's corners.
context.addPath(rounded(glass, screenRadius + border))
context.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1))
context.fillPath()
context.saveGState()
context.addPath(rounded(screen, screenRadius))
context.clip()
context.draw(load(capturePath), in: screen)
context.restoreGState()

// The Dynamic Island, over the capture's empty middle of the status bar.
let island = CGRect(
  x: screen.midX - 63 * point, y: screen.maxY - (11 + 37) * point,
  width: 126 * point, height: 37 * point)
context.addPath(rounded(island, island.height / 2))
context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
context.fillPath()

// No alpha channel: App Store Connect refuses panels that carry one.
guard let output = context.makeImage(),
  let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: outputPath) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("cannot write \(outputPath)") }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("cannot write \(outputPath)") }
