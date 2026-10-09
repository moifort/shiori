// Draws an iPhone 17 Pro Max around a capture, on a plain backdrop or a
// photograph, for the panels that show the app alone — and, side by side, for
// the product page's header.
//
// Drawn rather than generated: the image model's phones are never the real
// proportions, and a capture fitted onto one either squeezes or leaves a strip
// along the glass. Drawn to the device's own geometry, the capture fills the
// screen to the pixel. A panel's caption is set afterwards (finish-panel.swift).
//
// The header is the 16:9 "universal" creative asset, 5244x2950, which the App
// Store crops to 21:9 for the product page's header and to 3:2 for the search
// results: three phones in the band both crops keep, no text, so the store's own
// name and button over it read alone.
//
// Usage: swift device-panel.swift <#RRGGBB | backdrop.jpg> <capture.png> <out.png>
//        swift device-panel.swift header <#RRGGBB> <left.png> <centre.png> <right.png> <out.png>

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

func color(_ hex: String) -> CGColor? {
  guard hex.hasPrefix("#"), let value = Int(hex.dropFirst(), radix: 16) else { return nil }
  return CGColor(
    red: Double(value >> 16 & 255) / 255, green: Double(value >> 8 & 255) / 255,
    blue: Double(value & 255) / 255, alpha: 1)
}

func canvas(width: Int, height: Int) -> CGContext {
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fail("cannot allocate the canvas") }
  context.interpolationQuality = .high
  return context
}

/// The backdrop: a flat colour, or a photograph scaled to cover the canvas.
func paint(_ backdrop: String, on context: CGContext) {
  let (width, height) = (Double(context.width), Double(context.height))
  if let flat = color(backdrop) {
    context.setFillColor(flat)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return
  }
  let image = load(backdrop)
  let scale = max(width / Double(image.width), height / Double(image.height))
  let size = CGSize(width: Double(image.width) * scale, height: Double(image.height) * scale)
  context.draw(
    image,
    in: CGRect(
      x: (width - size.width) / 2, y: (height - size.height) / 2,
      width: size.width, height: size.height))
}

func rounded(_ rect: CGRect, _ radius: Double) -> CGPath {
  CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// The device, in the iPhone 17 Pro Max's own proportions: a 440x956-point
/// display, a black border a little under 2% of its width, a titanium band
/// around it, the Dynamic Island 126x37 points, 11 points from the top.
/// `screen` is the display's rectangle, in the context's bottom-up coordinates.
func drawDevice(_ capture: CGImage, screen: CGRect, in context: CGContext) {
  let point = screen.height / 956
  let border = 7 * point
  let band = 4.5 * point
  let screenRadius = 55 * point
  let glass = screen.insetBy(dx: -border, dy: -border)
  let body = glass.insetBy(dx: -band, dy: -band)

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
  context.draw(capture, in: screen)
  context.restoreGState()

  // The Dynamic Island, over the capture's empty middle of the status bar.
  let island = CGRect(
    x: screen.midX - 63 * point, y: screen.maxY - (11 + 37) * point,
    width: 126 * point, height: 37 * point)
  context.addPath(rounded(island, island.height / 2))
  context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
  context.fillPath()
}

/// No alpha channel: App Store Connect refuses images that carry one.
func write(_ context: CGContext, to path: String) {
  guard let output = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { fail("cannot write \(path)") }
  CGImageDestinationAddImage(destination, output, nil)
  guard CGImageDestinationFinalize(destination) else { fail("cannot write \(path)") }
}

let arguments = CommandLine.arguments

if arguments.count == 7, arguments[1] == "header" {
  // 5244x2950. The 21:9 header keeps the middle 2247 rows, the 3:2 search card
  // the middle 4425 columns: the phones stay inside both, the centre one forward.
  let (width, height) = (5244, 2950)
  let context = canvas(width: width, height: height)
  paint(arguments[2], on: context)
  let keptHeight = Double(width) * 9 / 21
  let keptBottom = (Double(height) - keptHeight) / 2
  let sides = [(arguments[3], -1.0), (arguments[5], 1.0)]
  let centreHeight = keptHeight * 0.92
  let sideHeight = centreHeight * 0.86
  let spacing = 440 * centreHeight / 956 * 0.98
  for (path, side) in sides {
    let screenWidth = 440 * sideHeight / 956
    let screen = CGRect(
      x: Double(width) / 2 + side * spacing - screenWidth / 2,
      y: keptBottom + (keptHeight - sideHeight) / 2,
      width: screenWidth, height: sideHeight)
    drawDevice(load(path), screen: screen, in: context)
  }
  let centreWidth = 440 * centreHeight / 956
  drawDevice(
    load(arguments[4]),
    screen: CGRect(
      x: (Double(width) - centreWidth) / 2, y: keptBottom + (keptHeight - centreHeight) / 2,
      width: centreWidth, height: centreHeight),
    in: context)
  write(context, to: arguments[6])
} else if arguments.count == 4 {
  // A panel, 1320x2868: the screen takes three quarters of its height, under
  // the caption band.
  let (width, height) = (1320, 2868)
  let context = canvas(width: width, height: height)
  paint(arguments[1], on: context)
  let screenHeight = Double(height) * 0.75
  let screenWidth = 440 * screenHeight / 956
  drawDevice(
    load(arguments[2]),
    screen: CGRect(
      x: (Double(width) - screenWidth) / 2, y: Double(height) * 0.055,
      width: screenWidth, height: screenHeight),
    in: context)
  write(context, to: arguments[3])
} else {
  fail(
    "usage: device-panel.swift <#RRGGBB | backdrop.jpg> <capture.png> <out.png>\n"
      + "       device-panel.swift header <#RRGGBB> <left.png> <centre.png> <right.png> <out.png>")
}
