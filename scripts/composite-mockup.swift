// Puts a real app capture onto the green screen of a generated photograph.
//
// The image model draws the hands and the phone, with a display of flat
// chroma-key green; it is never asked to draw the app, whose text it garbles.
// This finds the green, fits the capture onto it in perspective, and keeps the
// photograph wherever the green is not — a thumb over the edge, the Dynamic
// Island, the bezel — so the capture sits in the glass rather than on top of it.
//
// The model draws phones taller and narrower than an iPhone 17 Pro Max, whatever
// it is told, and a capture stretched onto such a screen comes out squeezed. So
// the photograph is first widened around its phones until their screens have the
// capture's proportions — on a plain backdrop, a hand a tenth wider goes
// unnoticed, where a squeezed interface does not — and the capture goes on as it
// is. With KEY=magenta the same is done for a book cover, without the widening.
//
// One photograph may hold several screens (two friends showing each other their
// phones): the regions are taken top to bottom, then left to right, one capture
// each. A capture written `name.png@180` goes on a phone held upside down.
//
// Usage: swift composite-mockup.swift <photo.png> <out.png> <capture.png>[@180] ...

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else {
  fail("usage: composite-mockup.swift <photo.png> <out.png> <capture.png>[@180] ...")
}
let photoURL = URL(fileURLWithPath: arguments[1])
let outURL = URL(fileURLWithPath: arguments[2])
let captures = arguments.dropFirst(3).map { argument in
  argument.hasSuffix("@180")
    ? (url: URL(fileURLWithPath: String(argument.dropLast(4))), upsideDown: true)
    : (url: URL(fileURLWithPath: argument), upsideDown: false)
}

/// The key colour: the phone's green, or with KEY=magenta a book cover's magenta.
let magenta = ProcessInfo.processInfo.environment["KEY"] == "magenta"
let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CIContext(options: [.workingColorSpace: sRGB])

guard let original = CIImage(contentsOf: photoURL) else { fail("cannot read \(photoURL.path)") }
let extent = original.extent
let width = Int(extent.width)
let height = Int(extent.height)
let step = 4
let gridWidth = width / step, gridHeight = height / step

/// A photograph as RGBA bytes, rows top to bottom, and its keyed screens.
struct Analysis {
  var pixels: [UInt8]
  var screens: [[Int]]

  /// How far a pixel leans toward the key, in levels.
  func keyExcess(_ index: Int) -> Int {
    let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
    return magenta ? min(r, b) - g : g - max(r, b)
  }

  func isKey(_ index: Int) -> Bool {
    let r = Int(pixels[index]), g = Int(pixels[index + 1]), b = Int(pixels[index + 2])
    return keyExcess(index) > 45 && (magenta ? min(r, b) > 110 : g > 110)
  }
}

func analyse(_ photo: CIImage) -> Analysis {
  var analysis = Analysis(pixels: [UInt8](repeating: 0, count: width * height * 4), screens: [])
  context.render(
    photo, toBitmap: &analysis.pixels, rowBytes: width * 4, bounds: extent, format: .RGBA8,
    colorSpace: sRGB)
  // The keyed pixels, grouped into screens: the connected regions of a grid four
  // pixels apart, the specks a reflection leaves aside.
  var region = [Int](repeating: -1, count: gridWidth * gridHeight)
  var found: [(cells: [Int], minX: Int, minY: Int)] = []
  for start in 0..<(gridWidth * gridHeight) where region[start] == -1 {
    let (sx, sy) = (start % gridWidth, start / gridWidth)
    guard analysis.isKey((sy * step * width + sx * step) * 4) else { continue }
    var stack = [start], cells: [Int] = []
    region[start] = found.count
    while let cell = stack.popLast() {
      cells.append(cell)
      let (cx, cy) = (cell % gridWidth, cell / gridWidth)
      for (nx, ny) in [(cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)]
      where nx >= 0 && ny >= 0 && nx < gridWidth && ny < gridHeight {
        let next = ny * gridWidth + nx
        if region[next] == -1, analysis.isKey((ny * step * width + nx * step) * 4) {
          region[next] = found.count
          stack.append(next)
        }
      }
    }
    found.append((cells, cells.map { $0 % gridWidth }.min()!, cells.map { $0 / gridWidth }.min()!))
  }
  analysis.screens = found.filter { $0.cells.count > gridWidth * gridHeight / 100 }
    .sorted { abs($0.minY - $1.minY) > gridHeight / 10 ? $0.minY < $1.minY : $0.minX < $1.minX }
    .map(\.cells)
  return analysis
}

/// The four corners of one screen, in image coordinates (origin top left): the
/// keyed cells furthest along each diagonal, pushed out by the rounding of the
/// glass, which the extreme points sit inside of.
func corners(of cells: [Int]) -> [CGPoint] {
  var topLeft = CGPoint.zero, topRight = topLeft, bottomLeft = topLeft, bottomRight = topLeft
  var best = (tl: Int.max, tr: Int.min, bl: Int.min, br: Int.min)
  for cell in cells {
    let (x, y) = (cell % gridWidth * step, cell / gridWidth * step)
    if x + y < best.tl { best.tl = x + y; topLeft = CGPoint(x: x, y: y) }
    if x - y > best.tr { best.tr = x - y; topRight = CGPoint(x: x, y: y) }
    if y - x > best.bl { best.bl = y - x; bottomLeft = CGPoint(x: x, y: y) }
    if x + y > best.br { best.br = x + y; bottomRight = CGPoint(x: x, y: y) }
  }
  let quad = [topLeft, topRight, bottomRight, bottomLeft]
  let center = CGPoint(x: quad.map(\.x).reduce(0, +) / 4, y: quad.map(\.y).reduce(0, +) / 4)
  let grow = 1.04
  return quad.map {
    CGPoint(x: center.x + ($0.x - center.x) * grow, y: center.y + ($0.y - center.y) * grow)
  }
}

/// Width over height of a screen, along its edges.
func ratio(of quad: [CGPoint]) -> Double {
  let width = (hypot(quad[1].x - quad[0].x, quad[1].y - quad[0].y)
    + hypot(quad[2].x - quad[3].x, quad[2].y - quad[3].y)) / 2
  let height = (hypot(quad[3].x - quad[0].x, quad[3].y - quad[0].y)
    + hypot(quad[2].x - quad[1].x, quad[2].y - quad[1].y)) / 2
  return width / height
}

var photo = original
var analysis = analyse(photo)
guard analysis.screens.count == captures.count else {
  fail("found \(analysis.screens.count) keyed screens for \(captures.count) captures")
}

// Widened around the screens until they have the capture's proportions.
if !magenta, let first = CIImage(contentsOf: captures[0].url) {
  let target = first.extent.width / first.extent.height
  let quads = analysis.screens.map(corners)
  let current = quads.map(ratio).reduce(0, +) / Double(quads.count)
  if current < target * 0.995 {
    let centerX = quads.flatMap { $0 }.map(\.x).reduce(0, +) / Double(quads.count * 4)
    // No further than keeps every phone in the frame, with its body around the
    // glass: two phones side by side would otherwise be pushed out of it. What
    // is left is cut off the capture's sides below.
    let room = quads.map { quad -> Double in
      let body = (quad.map(\.x).max()! - quad.map(\.x).min()!) * 0.08
      return quad.map { point -> Double in
        point.x < centerX
          ? (centerX - 0) / max(1, centerX - point.x + body)
          : (Double(width) - centerX) / max(1, point.x - centerX + body)
      }.min()!
    }.min()!
    let factor = min(target / current, max(1, room))
    photo = original.transformed(
      by: CGAffineTransform(translationX: -centerX, y: 0)
        .concatenating(CGAffineTransform(scaleX: factor, y: 1))
        .concatenating(CGAffineTransform(translationX: centerX, y: 0))
    ).cropped(to: extent)
    analysis = analyse(photo)
    guard analysis.screens.count == captures.count else {
      fail("found \(analysis.screens.count) keyed screens after widening")
    }
  }
}

// The mask: the key where the capture shows through, softened by a pixel so its
// edge against a finger or the bezel is not a staircase.
var maskBytes = [UInt8](repeating: 0, count: width * height)
for i in 0..<(width * height) where analysis.isKey(i * 4) { maskBytes[i] = 255 }
let mask = CIImage(
  bitmapData: Data(maskBytes), bytesPerRow: width, size: extent.size, format: .L8, colorSpace: nil
).applyingGaussianBlur(sigma: 1.2).cropped(to: extent)

// The key's light on the bezel and the fingers next to the screen: a pixel that
// leans toward the key without being it gets the lean taken out.
var pixels = analysis.pixels
for i in stride(from: 0, to: pixels.count, by: 4) where !analysis.isKey(i) && analysis.keyExcess(i) > 8 {
  if magenta {
    let floor = Int(pixels[i + 1])
    pixels[i] = UInt8(min(Int(pixels[i]), floor + 8))
    pixels[i + 2] = UInt8(min(Int(pixels[i + 2]), floor + 8))
  } else {
    pixels[i + 1] = max(pixels[i], pixels[i + 2])
  }
}
var composite = CIImage(
  bitmapData: Data(pixels), bytesPerRow: width * 4, size: extent.size, format: .RGBA8,
  colorSpace: sRGB)

for (cells, capture) in zip(analysis.screens, captures) {
  guard let image = CIImage(contentsOf: capture.url) else { fail("cannot read \(capture.url.path)") }
  var quad = corners(of: cells)
  // What is left of a difference in proportions is cut evenly off the capture's
  // sides or ends, never stretched.
  let screenRatio = ratio(of: quad)
  let full = image.extent
  let kept = full.width / full.height > screenRatio
    ? CGRect(
      x: full.midX - full.height * screenRatio / 2, y: full.minY,
      width: full.height * screenRatio, height: full.height)
    : CGRect(
      x: full.minX, y: full.midY - full.width / screenRatio / 2,
      width: full.width, height: full.width / screenRatio)
  let source = image.cropped(to: kept)
    .transformed(by: CGAffineTransform(translationX: -kept.minX, y: -kept.minY))
  // Upside down, the capture's top left lands on the screen's bottom right.
  if capture.upsideDown { quad = [quad[2], quad[3], quad[0], quad[1]] }
  // Core Image counts from the bottom.
  func flip(_ point: CGPoint) -> CIVector { CIVector(x: point.x, y: CGFloat(height) - point.y) }
  let warped = source.applyingFilter(
    "CIPerspectiveTransform",
    parameters: [
      "inputTopLeft": flip(quad[0]), "inputTopRight": flip(quad[1]),
      "inputBottomRight": flip(quad[2]), "inputBottomLeft": flip(quad[3]),
    ])
  // This screen's key alone: elsewhere the capture is empty, and the other
  // screens must keep what they already show.
  var own = [UInt8](repeating: 0, count: width * height)
  for cell in cells {
    let (gx, gy) = (cell % gridWidth * step, cell / gridWidth * step)
    for y in max(0, gy - step)..<min(height, gy + 2 * step) {
      for x in max(0, gx - step)..<min(width, gx + 2 * step) { own[y * width + x] = 255 }
    }
  }
  let region = CIImage(
    bitmapData: Data(own), bytesPerRow: width, size: extent.size, format: .L8, colorSpace: nil)
  let screenMask = mask.applyingFilter(
    "CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: region])
  composite = warped.applyingFilter(
    "CIBlendWithMask",
    parameters: [kCIInputBackgroundImageKey: composite, kCIInputMaskImageKey: screenMask]
  ).cropped(to: extent)
}

// No alpha channel: App Store Connect refuses panels that carry one.
guard
  let image = context.createCGImage(composite, from: extent),
  let flattened = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { fail("cannot render") }
flattened.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
guard
  let output = flattened.makeImage(),
  let destination = CGImageDestinationCreateWithURL(
    outURL as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("cannot write \(outURL.path)") }
CGImageDestinationAddImage(destination, output, nil)
CGImageDestinationFinalize(destination)
