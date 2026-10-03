// Turns a generated photograph into an App Store panel, in two steps around the
// screen compositing (composite-mockup.swift):
//
//   fit      scales and crops it to the 6.9" panel, 1320x2868, and with --backdrop
//            brings its background to the listing's exact grey, so panels drawn
//            one at a time meet without a visible change of colour;
//   caption  sets the caption in the band at the top, dark on a light background
//            and light on a dark one.
//
// The captions are set here rather than asked of the image model, which garbles
// text: Core Text, the system font, shrunk and wrapped until it fits the band.
//
// Usage: swift finish-panel.swift fit <in.png> <out.png> [--backdrop] [--anchor left|center|right] [--center <0-1>]
//        swift finish-panel.swift caption <in.png> <out.png> <caption>

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let panelWidth = 1320
let panelHeight = 2868
/// #F2F2F4, the listing's very light grey.
let backdropColor = (r: 242.0 / 255, g: 242.0 / 255, b: 244.0 / 255)

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

func canvas() -> CGContext {
  guard
    let context = CGContext(
      data: nil, width: panelWidth, height: panelHeight, bitsPerComponent: 8, bytesPerRow: 0,
      space: CGColorSpace(name: CGColorSpace.sRGB)!,
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fail("cannot allocate the panel") }
  return context
}

/// No alpha channel: App Store Connect refuses panels that carry one.
func write(_ context: CGContext, to path: String) {
  guard let image = context.makeImage(),
    let destination = CGImageDestinationCreateWithURL(
      URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
  else { fail("cannot write \(path)") }
  CGImageDestinationAddImage(destination, image, nil)
  guard CGImageDestinationFinalize(destination) else { fail("cannot write \(path)") }
}

/// The mean colour of a box of the image, from its pixels, 0...1.
func mean(of context: CGContext, in box: CGRect) -> (r: Double, g: Double, b: Double) {
  guard let data = context.data else { return (0, 0, 0) }
  let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * context.height)
  var sum = (r: 0.0, g: 0.0, b: 0.0), count = 0.0
  // The bitmap's rows run from the top; the box is in Core Graphics' coordinates,
  // which run from the bottom.
  for y in (context.height - Int(box.maxY))..<(context.height - Int(box.minY)) {
    for x in Int(box.minX)..<Int(box.maxX) {
      let offset = y * context.bytesPerRow + x * 4
      sum.r += Double(bytes[offset]); sum.g += Double(bytes[offset + 1]); sum.b += Double(bytes[offset + 2])
      count += 1
    }
  }
  return (sum.r / count / 255, sum.g / count / 255, sum.b / count / 255)
}

let arguments = CommandLine.arguments
guard arguments.count >= 4 else { fail("usage: finish-panel.swift fit|caption <in> <out> ...") }
let (mode, input, output) = (arguments[1], arguments[2], arguments[3])
let options = Array(arguments.dropFirst(4))

switch mode {
case "fit":
  let image = load(input)
  // Scaled to the panel's height, then cut to its width where the anchor says:
  // the left half of a pair keeps its right edge, which meets the other half.
  let scale = Double(panelHeight) / Double(image.height)
  let scaledWidth = Double(image.width) * scale
  let anchor = options.firstIndex(of: "--anchor").map { options[$0 + 1] } ?? "center"
  // --center places the panel's middle at that share of the scene's width, for a
  // subject that is not quite centred.
  let center = options.firstIndex(of: "--center").flatMap { Double(options[$0 + 1]) }
  let x: Double =
    if let center { Double(panelWidth) / 2 - scaledWidth * center } else {
      switch anchor {
      case "left": 0
      case "right": Double(panelWidth) - scaledWidth
      default: (Double(panelWidth) - scaledWidth) / 2
      }
    }
  let context = canvas()
  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: x, y: 0, width: scaledWidth, height: Double(panelHeight)))

  if options.contains("--backdrop"), let data = context.data {
    // The backdrop is never quite flat: the sweep darkens toward one side, and
    // two panels drawn apart would meet on a step of colour. So it is read all
    // around the border, the points that fall on the subject (a hand, a book)
    // set aside, and every pixel is corrected by what brings the backdrop near
    // it to the listing's grey — a correction that varies across the panel as the light does.
    let bytes = data.bindMemory(to: UInt8.self, capacity: context.bytesPerRow * panelHeight)
    let row = context.bytesPerRow
    func sample(_ x: Int, _ y: Int) -> (x: Double, y: Double, r: Double, g: Double, b: Double) {
      var sum = (r: 0.0, g: 0.0, b: 0.0)
      for dy in -6...6 {
        for dx in -6...6 {
          let offset = (y + dy) * row + (x + dx) * 4
          sum.r += Double(bytes[offset]); sum.g += Double(bytes[offset + 1]); sum.b += Double(bytes[offset + 2])
        }
      }
      return (Double(x), Double(y), sum.r / 169, sum.g / 169, sum.b / 169)
    }
    let margin = 24
    var points: [(x: Double, y: Double, r: Double, g: Double, b: Double)] = []
    for i in 0...8 {
      let x = margin + i * (panelWidth - 2 * margin) / 8
      points.append(sample(x, margin))
      points.append(sample(x, panelHeight - margin))
    }
    for i in 1...11 {
      let y = margin + i * (panelHeight - 2 * margin) / 12
      points.append(sample(margin, y))
      points.append(sample(panelWidth - margin, y))
    }
    let brightness = points.map { $0.r + $0.g + $0.b }.sorted()
    let median = brightness[brightness.count / 2]
    let backdrop = points.filter { abs($0.r + $0.g + $0.b - median) < 45 }
    guard backdrop.count >= 6 else { fail("no backdrop to read in \(input)") }
    let targets = (r: backdropColor.r * 255, g: backdropColor.g * 255, b: backdropColor.b * 255)
    // Gains on a coarse grid, by inverse-distance weighting of the backdrop
    // points, then applied per pixel from the nearest grid cell.
    let cell = 12
    let columns = panelWidth / cell + 1, rows = panelHeight / cell + 1
    var gains = [(Double, Double, Double)](repeating: (1, 1, 1), count: columns * rows)
    for gy in 0..<rows {
      for gx in 0..<columns {
        var weight = 0.0, sum = (r: 0.0, g: 0.0, b: 0.0)
        for point in backdrop {
          let dx = point.x - Double(gx * cell), dy = point.y - Double(gy * cell)
          let w = 1 / (dx * dx + dy * dy + 1)
          weight += w
          sum.r += w * targets.r / point.r; sum.g += w * targets.g / point.g; sum.b += w * targets.b / point.b
        }
        gains[gy * columns + gx] = (sum.r / weight, sum.g / weight, sum.b / weight)
      }
    }
    for y in 0..<panelHeight {
      for x in 0..<panelWidth {
        let gain = gains[(y / cell) * columns + x / cell]
        let offset = y * row + x * 4
        bytes[offset] = UInt8(min(255, Double(bytes[offset]) * gain.0))
        bytes[offset + 1] = UInt8(min(255, Double(bytes[offset + 1]) * gain.1))
        bytes[offset + 2] = UInt8(min(255, Double(bytes[offset + 2]) * gain.2))
      }
    }
  }
  write(context, to: output)

case "caption":
  guard let caption = options.first, !caption.isEmpty else { fail("no caption") }
  let image = load(input)
  let context = canvas()
  context.draw(image, in: CGRect(x: 0, y: 0, width: panelWidth, height: panelHeight))

  // The band: the top 15% of the panel, inset at the sides.
  let bandHeight = Double(panelHeight) * 0.15
  let inset = Double(panelWidth) * 0.08
  let band = CGRect(
    x: inset, y: Double(panelHeight) - bandHeight, width: Double(panelWidth) - inset * 2,
    height: bandHeight)
  let background = mean(of: context, in: band)
  let light = 0.299 * background.r + 0.587 * background.g + 0.114 * background.b > 0.55
  let ink = light
    ? CGColor(red: 0.16, green: 0.12, blue: 0.10, alpha: 1)
    : CGColor(red: backdropColor.r, green: backdropColor.g, blue: backdropColor.b, alpha: 1)

  var alignment = CTTextAlignment.center
  let paragraph = withUnsafeBytes(of: &alignment) { buffer -> CTParagraphStyle in
    var setting = CTParagraphStyleSetting(
      spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: buffer.baseAddress!)
    return CTParagraphStyleCreate(&setting, 1)
  }
  var fitted: (CTFramesetter, CGSize, Double)?
  for size in stride(from: Double(panelWidth) * 0.085, to: Double(panelWidth) * 0.04, by: -2) {
    let font = CTFontCreateUIFontForLanguage(.emphasizedSystem, size, "fr" as CFString)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    let attributed = NSAttributedString(
      string: caption,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): ink,
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let measured = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter, CFRange(location: 0, length: 0), nil,
      CGSize(width: band.width, height: .greatestFiniteMagnitude), nil)
    if measured.height <= band.height * 0.8 {
      fitted = (framesetter, measured, size)
      break
    }
  }
  guard let (framesetter, size, fontSize) = fitted else { fail("the caption does not fit: \(caption)") }
  // Centred in the band, a little below its middle: the panel's top edge is
  // where the store's rounded corner bites.
  let box = CGRect(
    x: band.minX, y: band.midY - size.height / 2 - bandHeight * 0.05, width: band.width,
    height: size.height)
  context.saveGState()
  if !light {
    context.setShadow(offset: .zero, blur: fontSize * 0.4, color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.7))
  }
  CTFrameDraw(
    CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), CGPath(rect: box, transform: nil), nil),
    context)
  context.restoreGState()
  write(context, to: output)

default:
  fail("unknown mode \(mode)")
}
