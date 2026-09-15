// Generates the custom SF-style symbols of the app (rocket, ghost, feather) as
// SF Symbols templates, one .symbolset per symbol, into a target directory.
// Shapes are drawn as centerlines at 100 pt, stroked with CoreGraphics at the
// Ultralight / Regular / Black widths measured on Apple's own "circle" symbol,
// then scaled onto Apple's template grid (392 units = cap height at 100 pt).
//
//   swift ios/tools/generate-symbols.swift ios/Shiori/Assets.xcassets
//
import AppKit

// ---------- geometry helpers (points at 100pt, y up, centered) ----------
let U: CGFloat = 5.571 // template units per point
struct Weight { let name: String; let stroke: CGFloat; let dot: CGFloat; let x: CGFloat }
let weights = [Weight(name: "Ultralight", stroke: 2.35, dot: 0.75, x: 559.219),
               Weight(name: "Regular",    stroke: 8.3,  dot: 1.0,  x: 1575.99),
               Weight(name: "Black",      stroke: 14.0, dot: 1.3, x: 2592.28)]

func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
func stroked(_ p: CGPath, _ w: CGFloat) -> CGPath {
    p.copy(strokingWithWidth: w, lineCap: .round, lineJoin: .round, miterLimit: 10)
}
func union(_ paths: [CGPath]) -> CGPath {
    let acc = CGMutablePath()
    for p in paths { acc.addPath(p.normalized(using: .winding)) }
    return acc
}
/// a filled shape with rounded corners: the fill plus its own stroke
func solid(_ p: CGPath, _ w: CGFloat) -> CGPath {
    let m = CGMutablePath(); m.addPath(p); m.addPath(stroked(p, w)); return m.normalized(using: .winding)
}
func rotated(_ p: CGPath, degrees: CGFloat) -> CGPath {
    var t = CGAffineTransform(rotationAngle: degrees * .pi / 180)
    return p.copy(using: &t)!
}
/// smooth wave segment with horizontal tangents
func wave(_ path: CGMutablePath, to p1: CGPoint) {
    let p0 = path.currentPoint
    let mx = (p0.x + p1.x) / 2
    path.addCurve(to: p1, control1: P(mx, p0.y), control2: P(mx, p1.y))
}

// ---------- symbols ----------
func rocket(_ w: Weight) -> CGPath {
    let s = w.stroke
    // body: ogive nose, straight flanks, flat base
    let body = CGMutablePath()
    body.move(to: P(0, 46))
    body.addCurve(to: P(19, 6), control1: P(13, 36), control2: P(19, 20))
    body.addLine(to: P(19, -28))
    body.addLine(to: P(-19, -28))
    body.addLine(to: P(-19, 6))
    body.addCurve(to: P(0, 46), control1: P(-19, 20), control2: P(-13, 36))
    body.closeSubpath()
    // fins and nozzle: solid, rounded
    let finR = CGMutablePath()
    finR.move(to: P(19, -12)); finR.addLine(to: P(31, -33)); finR.addLine(to: P(19, -30)); finR.closeSubpath()
    let finL = CGMutablePath()
    finL.move(to: P(-19, -12)); finL.addLine(to: P(-31, -33)); finL.addLine(to: P(-19, -30)); finL.closeSubpath()
    let nozzle = CGMutablePath()
    nozzle.move(to: P(-7, -28)); nozzle.addLine(to: P(-9, -38)); nozzle.addLine(to: P(9, -38)); nozzle.addLine(to: P(7, -28)); nozzle.closeSubpath()
    let port = CGMutablePath()
    port.addEllipse(in: CGRect(x: -8, y: 4, width: 16, height: 16))
    let all = union([stroked(body, s), solid(finR, s * 0.6), solid(finL, s * 0.6), solid(nozzle, s * 0.6), stroked(port, s * 0.85)])
    return rotated(all, degrees: -40)
}

func ghost(_ w: Weight) -> CGPath {
    let s = w.stroke
    let sheet = CGMutablePath()
    sheet.move(to: P(35, 4))
    sheet.addArc(center: P(0, 4), radius: 35, startAngle: 0, endAngle: .pi, clockwise: false) // dome, to (-35, 4)
    sheet.addLine(to: P(-35, -38))
    wave(sheet, to: P(-23.3, -26))
    wave(sheet, to: P(-11.7, -38))
    wave(sheet, to: P(0, -26))
    wave(sheet, to: P(11.7, -38))
    wave(sheet, to: P(23.3, -26))
    wave(sheet, to: P(35, -38))
    sheet.closeSubpath()
    let eyes = CGMutablePath()
    let r: CGFloat = 5.5 * w.dot
    eyes.addEllipse(in: CGRect(x: -13 - r, y: 6 - r * 1.25, width: 2 * r, height: 2.5 * r))
    eyes.addEllipse(in: CGRect(x: 13 - r, y: 6 - r * 1.25, width: 2 * r, height: 2.5 * r))
    let m = CGMutablePath(); m.addPath(stroked(sheet, s)); m.addPath(eyes); return m
}

func feather(_ w: Weight) -> CGPath {
    let s = w.stroke
    // built along the x axis: quill from -44 to 0, vane from 0 to 66, tip at 66
    let L: CGFloat = 72
    let vane = CGMutablePath()
    vane.move(to: P(L, 4))                                                       // tip, lifted
    vane.addCurve(to: P(L * 0.62, 17), control1: P(L * 0.9, 12), control2: P(L * 0.78, 17))   // upper edge, first lobe
    vane.addLine(to: P(L * 0.55, 10))                                            // notch
    vane.addCurve(to: P(L * 0.3, 16), control1: P(L * 0.48, 16), control2: P(L * 0.4, 17))    // second lobe
    vane.addLine(to: P(L * 0.24, 9))                                             // notch
    vane.addCurve(to: P(0, 0), control1: P(L * 0.14, 12), control2: P(L * 0.04, 5))          // down to the base
    vane.addCurve(to: P(L * 0.5, -11), control1: P(L * 0.06, -6), control2: P(L * 0.25, -11))  // lower edge, narrower
    vane.addCurve(to: P(L, 4), control1: P(L * 0.78, -11), control2: P(L * 0.92, -3))
    vane.closeSubpath()
    let shaft = CGMutablePath()
    shaft.move(to: P(-40, 0)); shaft.addLine(to: P(L * 0.78, 1))
    let all = union([stroked(vane, s), stroked(shaft, s)])
    var t = CGAffineTransform(translationX: -14, y: 0).rotated(by: 0) // recenter along axis
    let centered = all.copy(using: &t)!
    return rotated(centered, degrees: 45)
}

// ---------- SVG emission ----------
func fmt(_ v: CGFloat) -> String { String(format: "%.2f", v) }
func svgPathData(_ path: CGPath) -> (String, CGRect) {
    var d = ""
    path.applyWithBlock { el in
        let e = el.pointee; let p = e.points
        switch e.type {
        case .moveToPoint: d += "M \(fmt(p[0].x * U)),\(fmt(-p[0].y * U)) "
        case .addLineToPoint: d += "L \(fmt(p[0].x * U)),\(fmt(-p[0].y * U)) "
        case .addQuadCurveToPoint: d += "Q \(fmt(p[0].x * U)),\(fmt(-p[0].y * U)) \(fmt(p[1].x * U)),\(fmt(-p[1].y * U)) "
        case .addCurveToPoint: d += "C \(fmt(p[0].x * U)),\(fmt(-p[0].y * U)) \(fmt(p[1].x * U)),\(fmt(-p[1].y * U)) \(fmt(p[2].x * U)),\(fmt(-p[2].y * U)) "
        case .closeSubpath: d += "Z "
        @unknown default: break
        }
    }
    return (d, path.boundingBoxOfPath)
}
func elementCount(_ p: CGPath) -> Int { var n = 0; p.applyWithBlock { _ in n += 1 }; return n }

func template(name: String, make: (Weight) -> CGPath) -> String {
    var groups = ""; var regularBox = CGRect.zero; var counts: [Int] = []
    for w in weights {
        let p = make(w); counts.append(elementCount(p))
        let (d, box) = svgPathData(p)
        if w.name == "Regular" { regularBox = box }
        groups += "  <g id=\"\(w.name)-M\" transform=\"matrix(1 0 0 1 \(w.x) 892.0)\">\n   <path d=\"\(d.trimmingCharacters(in: .whitespaces))\" style=\"fill:black;stroke:none;\"/>\n  </g>\n"
    }
    let left = 1575.99 + regularBox.minX * U - 4, right = 1575.99 + regularBox.maxX * U + 4
    print(name, "regular ink pt:", fmt(regularBox.width), "x", fmt(regularBox.height), "elements per weight:", counts)
    return """
<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!--glyph: "\(name)", point size: 100.0, template writer version: "8"-->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <line id="" style="fill:none;stroke:black;opacity:0.5;stroke-width:0.5;" x1="263" x2="3036" y1="292" y2="292"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Template v.3.0</text>
  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 263 1953)">\(name)</text>
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
  <line id="left-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(fmt(left))" x2="\(fmt(left))" y1="600.785" y2="1183.21"/>
  <line id="right-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="\(fmt(right))" x2="\(fmt(right))" y1="600.785" y2="1183.21"/>
 </g>
 <g id="Symbols">
\(groups) </g>
</svg>

"""
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/shiori-symbols"
let symbols: [(String, (Weight) -> CGPath)] = [("rocket", rocket), ("ghost", ghost), ("feather", feather)]
for (name, make) in symbols {
    let dir = "\(out)/\(name).symbolset"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try! template(name: name, make: make).write(toFile: "\(dir)/\(name).svg", atomically: true, encoding: .utf8)
    let contents = "{\n  \"info\" : {\n    \"author\" : \"xcode\",\n    \"version\" : 1\n  },\n  \"symbols\" : [\n    {\n      \"filename\" : \"\(name).svg\",\n      \"idiom\" : \"universal\"\n    }\n  ]\n}\n"
    try! contents.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
}
print("written")
