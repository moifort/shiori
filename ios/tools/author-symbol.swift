// The author symbol: Font Awesome's solid feather, made an SF Symbols template.
//
// The drawing is Font Awesome Free's "feather" (solid), by Fonticons, Inc.,
// https://fontawesome.com, licensed CC BY 4.0
// (https://creativecommons.org/licenses/by/4.0/); the attribution travels in the
// generated SVG. It is used as drawn: scaled to the ink box of Apple's symbols at
// 100 pt, and given three weights by growing or shrinking its outline with
// CoreGraphics, Regular being the drawing itself.
//
//   swift ios/tools/author-symbol.swift ios/Shiori/Assets.xcassets/author.symbolset
import CoreGraphics
import Foundation

let featherPath = "M278.5 215.6L23 471c-9.4 9.4-9.4 24.6 0 33.9s24.6 9.4 33.9 0l57-57 68 0c49.7 0 97.9-14.4 139-41c11.1-7.2 5.5-23-7.8-23c-5.1 0-9.2-4.1-9.2-9.2c0-4.1 2.7-7.6 6.5-8.8l81-24.3c2.5-.8 4.8-2.1 6.7-4l22.4-22.4c10.1-10.1 2.9-27.3-11.3-27.3l-32.2 0c-5.1 0-9.2-4.1-9.2-9.2c0-4.1 2.7-7.6 6.5-8.8l112-33.6c4-1.2 7.4-3.9 9.3-7.7C506.4 207.6 512 184.1 512 160c0-41-16.3-80.3-45.3-109.3l-5.5-5.5C432.3 16.3 393 0 352 0s-80.3 16.3-109.3 45.3L139 149C91 197 64 262.1 64 330l0 55.3L253.6 195.8c6.2-6.2 16.4-6.2 22.6 0c5.4 5.4 6.1 13.6 2.2 19.8z"

/// Points per template unit, and the ink the Regular weight spans at 100 pt
/// (the size the hand-drawn quill had, so every call site keeps its look).
let unit: CGFloat = 5.571
let inkSide: CGFloat = 76.6
/// How far each weight moves the outline, in points at 100 pt. Kept small: the
/// white shaft is a gap of about 5 pt, and Black must not close it.
let weights: [(name: String, offset: CGFloat, x: CGFloat)] = [
    ("Ultralight", -1.0, 559.219), ("Regular", 0, 1575.99), ("Black", 1.0, 2592.28),
]

// MARK: - SVG path parsing (M L H V C S Z, absolute and relative, implicit repeats)

func parse(_ d: String) -> CGPath {
    var tokens: [String] = []
    var number = ""
    func flush() { if !number.isEmpty { tokens.append(number); number = "" } }
    for ch in d {
        if ch.isLetter && ch != "e" { flush(); tokens.append(String(ch)) }
        else if ch == "-" && !number.isEmpty && !number.hasSuffix("e") { flush(); number = "-" }
        else if ch == "." && number.contains(".") { flush(); number = "." }
        else if ch == " " || ch == "," { flush() }
        else { number.append(ch) }
    }
    flush()

    let path = CGMutablePath()
    var i = 0, command: Character = "M"
    var current = CGPoint.zero, start = CGPoint.zero, lastControl: CGPoint?
    func next() -> CGFloat { defer { i += 1 }; return CGFloat(Double(tokens[i])!) }
    while i < tokens.count {
        if let c = tokens[i].first, c.isLetter { command = c; i += 1 }
        let relative = command.isLowercase
        let base = relative ? current : .zero
        switch command.uppercased() {
        case "M":
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.move(to: current); start = current; lastControl = nil
            command = relative ? "l" : "L"
        case "L":
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addLine(to: current); lastControl = nil
        case "H":
            current = CGPoint(x: (relative ? current.x : 0) + next(), y: current.y)
            path.addLine(to: current); lastControl = nil
        case "V":
            current = CGPoint(x: current.x, y: (relative ? current.y : 0) + next())
            path.addLine(to: current); lastControl = nil
        case "C":
            let c1 = CGPoint(x: base.x + next(), y: base.y + next())
            let c2 = CGPoint(x: base.x + next(), y: base.y + next())
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addCurve(to: current, control1: c1, control2: c2); lastControl = c2
        case "S":
            let c1 = lastControl.map { CGPoint(x: 2 * current.x - $0.x, y: 2 * current.y - $0.y) } ?? current
            let c2 = CGPoint(x: base.x + next(), y: base.y + next())
            current = CGPoint(x: base.x + next(), y: base.y + next())
            path.addCurve(to: current, control1: c1, control2: c2); lastControl = c2
        case "Z":
            path.closeSubpath(); current = start; lastControl = nil
        default:
            fatalError("unsupported path command \(command)")
        }
    }
    return path
}

// MARK: - Weights and emission

let drawing = parse(featherPath)
let box = drawing.boundingBoxOfPath
/// Drawing units per point at 100 pt.
let scale = max(box.width, box.height) / inkSide

func weighted(_ offset: CGFloat) -> CGPath {
    guard offset != 0 else { return drawing }
    let band = drawing.copy(strokingWithWidth: 2 * abs(offset) * scale, lineCap: .round, lineJoin: .round, miterLimit: 10)
    return offset > 0 ? drawing.union(band) : drawing.subtracting(band)
}

func f(_ v: CGFloat) -> String { String(format: "%.2f", Double(v)) }

func svg(_ path: CGPath) -> String {
    func p(_ q: CGPoint) -> String {
        "\(f((q.x - box.midX) / scale * unit)),\(f((q.y - box.midY) / scale * unit))"
    }
    var out: [String] = []
    path.applyWithBlock { element in
        let e = element.pointee, pts = e.points
        switch e.type {
        case .moveToPoint: out.append("M \(p(pts[0]))")
        case .addLineToPoint: out.append("L \(p(pts[0]))")
        case .addQuadCurveToPoint: out.append("Q \(p(pts[0])) \(p(pts[1]))")
        case .addCurveToPoint: out.append("C \(p(pts[0])) \(p(pts[1])) \(p(pts[2]))")
        case .closeSubpath: out.append("Z")
        @unknown default: break
        }
    }
    return out.joined(separator: " ")
}

let groups = weights.map { w in
    "  <g id=\"\(w.name)-M\" transform=\"matrix(1 0 0 1 \(w.x) 892.0)\">\n   <path d=\"\(svg(weighted(w.offset)))\" style=\"fill:black;stroke:none;\"/>\n  </g>\n"
}.joined()
let half = inkSide / 2 * unit
let left = 1575.99 - half - 4, right = 1575.99 + half + 4

let template = """
<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!--glyph: "author", point size: 100.0, template writer version: "8"-->
 <!--Font Awesome Free "feather" (solid) by Fonticons, Inc. - https://fontawesome.com - License CC BY 4.0: https://creativecommons.org/licenses/by/4.0/-->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <line id="" style="fill:none;stroke:black;opacity:0.5;stroke-width:0.5;" x1="263" x2="3036" y1="292" y2="292"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Template v.3.0</text>
  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 263 1953)">author</text>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 559.219 1993)">Ultralight</text>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 1575.99 1993)">Regular</text>
  <text style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 2592.28 1993)">Black</text>
 </g>
 <g id="Guides">
  <line id="Capline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
  <line id="Baseline-S" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1088" y2="1088"/>
  <line id="Capline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
  <line id="Baseline-M" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1088" y2="1088"/>
  <line id="Capline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="696" y2="696"/>
  <line id="Baseline-L" style="fill:none;stroke:#27AAE1;opacity:1;stroke-width:0.5;" x1="263" x2="3036" y1="1088" y2="1088"/>
  <line id="left-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(f(left))" x2="\(f(left))" y1="600.785" y2="1183.21"/>
  <line id="right-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(f(right))" x2="\(f(right))" y1="600.785" y2="1183.21"/>
 </g>
 <g id="Symbols">
\(groups) </g>
</svg>

"""

let out = CommandLine.arguments[1]
try! FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
try! template.write(toFile: "\(out)/author.svg", atomically: true, encoding: .utf8)
print("author: ink \(f(box.width / scale)) x \(f(box.height / scale)) pt")
