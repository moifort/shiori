// Draws a device per panel onto a generated App Store panorama (see
// generate-appstore-previews.ts), pastes the real app screenshot into each one,
// and sets the marketing caption above it.
//
// The panorama is split into as many equal columns as there are screenshots
// passed — two or three, whatever the panorama was cut for — and one phone is
// drawn dead centre of each. The panorama file is rewritten in place.
//
// The captions are drawn here rather than asked of the image model: the model
// mangles text it renders, and it would have to be trusted with seven languages
// including Japanese. Core Text sets them from the same font the app uses, so a
// German compound word wraps instead of overflowing and kana come out as kana.
//
// Usage: swift composite-panorama.swift <panorama.png> <language> <subtitle>
//                                       <screenshot> <caption> [<screenshot> <caption> ...]
//
// Language and subtitle may be empty; a panel with an empty caption gets its
// device and no text. The subtitle is set smaller under every caption, the same
// sentence on each panel: it says what the app does, while each caption says
// what its panel shows.

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("\(message)\n".utf8))
  exit(1)
}

func loadImage(_ path: String) -> CGImage {
  let url = URL(fileURLWithPath: path)
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
    let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
  else { fail("Cannot read image: \(path)") }
  return image
}

func rgbaBitmap(of image: CGImage, width: Int, height: Int) -> (CGContext, UnsafeMutablePointer<UInt8>) {
  let bytesPerRow = width * 4
  guard
    let context = CGContext(
      data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      // Opaque, and the alpha byte kept only to keep the four-byte pixel the
      // magenta scan reads. App Store Connect rejects a screenshot carrying an
      // alpha channel (IMAGE_ALPHA_NOT_ALLOWED), and the panels are opaque
      // anyway: the scene fills every one of them edge to edge.
      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
  else { fail("Cannot create bitmap context") }
  context.interpolationQuality = .high
  context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  guard let data = context.data else { fail("Bitmap context has no data") }
  return (context, data.assumingMemoryBound(to: UInt8.self))
}

// How strongly a pixel reads as the magenta placeholder, in 0...1.
func magentaWeight(_ pixels: UnsafeMutablePointer<UInt8>, _ offset: Int) -> Double {
  let r = Double(pixels[offset])
  let g = Double(pixels[offset + 1])
  let b = Double(pixels[offset + 2])
  return max(0, min(1, (min(r, b) - g - 60) / 80))
}

/// A piece of text measured at the largest size that fits the given width and
/// height, ready to be drawn wherever the caller decides.
struct FittedText {
  let framesetter: CTFramesetter
  let size: CGSize
  let fontSize: Double
}

/// Measures `text` at the largest size that fits, shrinking rather than
/// clipping: German runs long, Japanese runs short, and a caption that overflows
/// its band is worse than one set a size smaller. The size is expressed against
/// the panel width so the three panels carry the same weight of text, whatever
/// the language does with the wording.
func fitText(
  _ text: String, width: Double, maxHeight: Double, language: String,
  weight: Double = 1, opacity: Double = 1
) -> FittedText? {
  guard !text.isEmpty, maxHeight > 0 else { return nil }
  // Core Text reads the setting through a raw pointer, so the value has to
  // outlive the call that copies it — hence the explicit scope.
  var alignment = CTTextAlignment.center
  let paragraph = withUnsafeBytes(of: &alignment) { buffer -> CTParagraphStyle in
    var setting = CTParagraphStyleSetting(
      spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: buffer.baseAddress!)
    return CTParagraphStyleCreate(&setting, 1)
  }

  for size in stride(from: width * 0.075 * weight, to: width * 0.025 * weight, by: -2) {
    let font = CTFontCreateUIFontForLanguage(.system, size, language as CFString)
      ?? CTFontCreateWithName("Helvetica-Bold" as CFString, size, nil)
    // The Core Text attribute names, not AppKit's: this tool links neither
    // AppKit nor UIKit, and NSAttributedString.Key.font comes from those.
    let attributed = NSAttributedString(
      string: text,
      attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
          red: 1, green: 0.98, blue: 0.94, alpha: opacity),
        NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraph,
      ])
    let framesetter = CTFramesetterCreateWithAttributedString(attributed)
    let measured = CTFramesetterSuggestFrameSizeWithConstraints(
      framesetter, CFRange(location: 0, length: 0), nil,
      CGSize(width: width, height: .greatestFiniteMagnitude), nil)
    guard measured.height <= maxHeight, measured.width <= width else { continue }
    return FittedText(framesetter: framesetter, size: measured, fontSize: size)
  }
  return nil
}

/// Draws measured text with its top-left at `origin`, in a box `width` wide.
func draw(_ text: FittedText, x: Double, top: Double, width: Double, context: CGContext) {
  let box = CGRect(x: x, y: top - text.size.height, width: width, height: text.size.height)
  let frame = CTFramesetterCreateFrame(
    text.framesetter, CFRange(location: 0, length: 0), CGPath(rect: box, transform: nil), nil)
  context.saveGState()
  // A soft dark halo: the background is a photograph, and white text over a
  // bright reflection would disappear into it.
  context.setShadow(
    offset: .zero, blur: text.fontSize * 0.35,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.65))
  CTFrameDraw(frame, context)
  context.restoreGState()
}

let arguments = CommandLine.arguments
// One panorama, a language, a subtitle, then a (screenshot, caption) pair per
// panel — so an even count, six at the least.
guard arguments.count >= 6, arguments.count % 2 == 0 else {
  fail(
    "Usage: swift composite-panorama.swift <panorama.png> <language> <subtitle> <screenshot> <caption> [<screenshot> <caption> ...]"
  )
}
let panoramaPath = arguments[1]
let captionLanguage = arguments[2]
let subtitle = arguments[3]
let panels = stride(from: 4, to: arguments.count, by: 2).map {
  (screenshot: arguments[$0], caption: arguments[$0 + 1])
}
let panoramaImage = loadImage(panoramaPath)
let width = panoramaImage.width
let height = panoramaImage.height
let (panoramaContext, panorama) = rgbaBitmap(of: panoramaImage, width: width, height: height)

// The device is drawn here rather than generated: asked for a phone at a given
// size, the image model produced a different one every time and a different one
// per panel, and the panels are read side by side. Placed by hand, they line up
// to the pixel from one panel to the next and the screenshots never stretch.
let panelWidth = Double(width) / Double(panels.count)
// The screen, as a share of the panel's height. Large enough that the app is
// legible in a store thumbnail, small enough that the room still shows on both
// sides — past ~78% the background is a sliver and the triptych stops reading
// as one scene.
let screenHeight = Double(height) * 0.72
// The iPhone 17 Pro Max's own proportions: a 1320x2868 display, a bezel a
// little under 2% of the screen's width, and the rail around it about half as
// thick again.
let screenWidth = screenHeight * (1320.0 / 2868.0)
let bezel = screenWidth * 0.019
let rail = bezel * 1.4
let screenRadius = screenWidth * 0.115
// Top edge at 19% of the height, so the caption band above it is the same on
// every panel.
let deviceTop = Double(height) * 0.19

for (index, panel) in panels.enumerated() {
  let centerX = panelWidth * (Double(index) + 0.5)
  // Core Graphics counts y from the bottom; the framing above is expressed from
  // the top, as the panel is read.
  let screenRect = CGRect(
    x: centerX - screenWidth / 2,
    y: Double(height) - deviceTop - screenHeight,
    width: screenWidth,
    height: screenHeight)
  let bodyRect = screenRect.insetBy(dx: -(bezel + rail), dy: -(bezel + rail))
  let bodyRadius = screenRadius + bezel + rail

  // The titanium rail, drawn as a gradient across the body so the edge catches
  // the light the way a brushed metal band does — a flat grey reads as a
  // cardboard cut-out at this size.
  panoramaContext.saveGState()
  panoramaContext.setShadow(
    offset: CGSize(width: 0, height: -rail * 2), blur: rail * 6,
    color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.55))
  panoramaContext.addPath(
    CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil))
  panoramaContext.setFillColor(CGColor(red: 0.36, green: 0.35, blue: 0.34, alpha: 1))
  panoramaContext.fillPath()
  panoramaContext.restoreGState()

  panoramaContext.saveGState()
  panoramaContext.addPath(
    CGPath(roundedRect: bodyRect, cornerWidth: bodyRadius, cornerHeight: bodyRadius, transform: nil))
  panoramaContext.clip()
  if let rails = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
      CGColor(red: 0.78, green: 0.76, blue: 0.73, alpha: 1),
      CGColor(red: 0.30, green: 0.29, blue: 0.28, alpha: 1),
      CGColor(red: 0.55, green: 0.53, blue: 0.51, alpha: 1),
      CGColor(red: 0.24, green: 0.23, blue: 0.22, alpha: 1),
      CGColor(red: 0.72, green: 0.70, blue: 0.67, alpha: 1),
    ] as CFArray,
    locations: [0, 0.18, 0.5, 0.82, 1])
  {
    panoramaContext.drawLinearGradient(
      rails, start: CGPoint(x: bodyRect.minX, y: 0), end: CGPoint(x: bodyRect.maxX, y: 0),
      options: [])
  }
  panoramaContext.restoreGState()

  // The black glass between the rail and the picture.
  panoramaContext.saveGState()
  let glassRect = screenRect.insetBy(dx: -bezel, dy: -bezel)
  panoramaContext.addPath(
    CGPath(
      roundedRect: glassRect, cornerWidth: screenRadius + bezel, cornerHeight: screenRadius + bezel,
      transform: nil))
  panoramaContext.setFillColor(CGColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1))
  panoramaContext.fillPath()
  panoramaContext.restoreGState()

  // The side buttons: volume pair and action button on the left, the side
  // button on the right, at the heights the device carries them.
  panoramaContext.saveGState()
  panoramaContext.setFillColor(CGColor(red: 0.30, green: 0.29, blue: 0.28, alpha: 1))
  let buttonDepth = rail * 0.8
  let buttons: [(Double, Double, Bool)] = [
    (0.20, 0.035, true),  // action button
    (0.28, 0.075, true),  // volume up
    (0.38, 0.075, true),  // volume down
    (0.30, 0.115, false),  // side button
  ]
  for (top, length, isLeft) in buttons {
    let y = screenRect.maxY - screenHeight * top - screenHeight * length
    let x = isLeft ? bodyRect.minX - buttonDepth * 0.6 : bodyRect.maxX - buttonDepth * 0.4
    panoramaContext.addPath(
      CGPath(
        roundedRect: CGRect(x: x, y: y, width: buttonDepth, height: screenHeight * length),
        cornerWidth: buttonDepth / 2, cornerHeight: buttonDepth / 2, transform: nil))
  }
  panoramaContext.fillPath()
  panoramaContext.restoreGState()

  // The screenshot, clipped to the screen's rounded corners.
  panoramaContext.saveGState()
  panoramaContext.addPath(
    CGPath(
      roundedRect: screenRect, cornerWidth: screenRadius, cornerHeight: screenRadius,
      transform: nil))
  panoramaContext.clip()
  panoramaContext.draw(loadImage(panel.screenshot), in: screenRect)
  panoramaContext.restoreGState()

  guard !panel.caption.isEmpty else { continue }

  let minY = Int(deviceTop)
  let xStart = Int(panelWidth * Double(index))
  let xEnd = Int(panelWidth * Double(index + 1))

    // A dark scrim over the text area, drawn here rather than asked of the image
    // model: told to keep an area calm, it produced a blurred band with a hard
    // edge across the picture. A gradient we draw ourselves is even, predictable
    // and stops exactly where we say.
    let scrimHeight = Double(minY) * 1.15
    if let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        CGColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0.72),
        CGColor(red: 0.05, green: 0.03, blue: 0.02, alpha: 0),
      ] as CFArray,
      locations: [0, 1])
    {
      panoramaContext.saveGState()
      panoramaContext.clip(
        to: CGRect(
          x: Double(xStart), y: Double(height) - scrimHeight,
          width: Double(xEnd - xStart), height: scrimHeight))
      panoramaContext.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: Double(height)),
        end: CGPoint(x: 0, y: Double(height) - scrimHeight),
        options: [])
      panoramaContext.restoreGState()
    }

    let margin = Double(height) * 0.02
    let inset = Double(xEnd - xStart) * 0.08
    let band = CGRect(
      x: Double(xStart) + inset,
      y: Double(height - minY) + margin,
      width: Double(xEnd - xStart) - inset * 2,
      height: Double(minY) - margin * 2)

    // The title, and under it the sentence saying what the app does — measured
    // first, then drawn as one block centered in the band, so the two read as a
    // pair rather than as two things that happen to share an area.
    let titleHeight = subtitle.isEmpty ? band.height : band.height * 0.6
    guard
      let title = fitText(
        panel.caption, width: band.width, maxHeight: titleHeight,
        language: captionLanguage, weight: subtitle.isEmpty ? 1 : 1.15)
    else { continue }
    let sentence = fitText(
      subtitle, width: band.width * 0.95, maxHeight: band.height * 0.25,
      language: captionLanguage, weight: 0.55, opacity: 0.85)

    let gap = title.fontSize * 0.55
    let blockHeight = title.size.height + (sentence.map { gap + $0.size.height } ?? 0)
    var cursor = band.midY + blockHeight / 2
    draw(title, x: band.minX, top: cursor, width: band.width, context: panoramaContext)
    cursor -= title.size.height + gap
    if let sentence {
      draw(
        sentence, x: band.minX + band.width * 0.025, top: cursor, width: band.width * 0.95,
        context: panoramaContext)
    }
}

guard let output = panoramaContext.makeImage(),
  let destination = CGImageDestinationCreateWithURL(
    URL(fileURLWithPath: panoramaPath) as CFURL, UTType.png.identifier as CFString, 1, nil)
else { fail("Cannot encode output image") }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fail("Cannot write \(panoramaPath)") }
