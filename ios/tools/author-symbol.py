"""The author symbol: a quill, drawn by hand on Apple's 100 pt grid (y up).

The construction every icon family agrees on (Lucide, Phosphor, Tabler, Font
Awesome): the vane leans at 45°, round at its far end, cut square at its base
where the shaft leaves it for the nib; one barb line crosses the lower half from
the shaft to the edge. Every contour is exact geometry — offset lines, concentric
arcs, fillets, capsules — so the three weights share one drawing and differ only
by the stroke Apple's symbols carry at 100 pt."""
#   python3 ios/tools/author-symbol.py ios/Shiori/Assets.xcassets/author.symbolset
import math, sys, os

U = 5.571
WEIGHTS = [("Ultralight", 2.35, 559.219), ("Regular", 8.3, 1575.99), ("Black", 14.0, 2592.28)]

# ---------- the drawing, screen frame (x right, y up), the vane's base corner K at the origin ----------
R = 20.0            # the vane's half-width on the centreline (its round end's radius)
L = 62.0            # from K to the round end's centre, along the axis
NIB = 18.0          # the bare shaft from K down to the nib
RHO = 3.0           # fillet at the two base corners
BARB = 24.0         # the barb line sits this far below the round end's centre

S2 = math.sqrt(2) / 2
D = (S2, S2)        # along the quill, towards the round end
N = (-S2, S2)       # across it, up-left

def mul(v, k): return (v[0] * k, v[1] * k)
def add(a, b): return (a[0] + b[0], a[1] + b[1])
def dist(a, b): return math.hypot(a[0] - b[0], a[1] - b[1])
def ang(c, p): return math.atan2(p[1] - c[1], p[0] - c[0])

def meet(p1, d1, p2, d2):
    """intersection of the lines p1 + t d1 and p2 + u d2"""
    det = d1[0] * d2[1] - d1[1] * d2[0]
    t = ((p2[0] - p1[0]) * d2[1] - (p2[1] - p1[1]) * d2[0]) / det
    return (p1[0] + t * d1[0], p1[1] + t * d1[1])

K = (0.0, 0.0)
C = mul(D, L)                                   # centre of the round end
A = (0.0, R * math.sqrt(2))                     # top of the vertical base edge
B = (R * math.sqrt(2), 0.0)                     # right end of the horizontal base edge
F_A = meet((RHO, 0.0), (0.0, 1.0), add(K, mul(N, R - RHO)), D)     # fillet centre at A
F_B = meet((0.0, RHO), (1.0, 0.0), add(K, mul(N, -(R - RHO))), D)  # fillet centre at B

class Contour:
    def __init__(self): self.cmds = []; self.cur = None
    def move(self, p): self.cmds.append(("M", p)); self.cur = p
    def line(self, p):
        if self.cur is None: self.move(p)
        elif dist(self.cur, p) > 1e-6: self.cmds.append(("L", p)); self.cur = p
    def arc(self, c, r, a0, a1):
        if r <= 1e-9: self.line(c); return
        total = a1 - a0
        n = max(1, int(math.ceil(abs(total) / (math.pi / 2) - 1e-9)))
        step = total / n
        k = 4 / 3 * math.tan(step / 4)
        a = a0
        self.line((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
        for _ in range(n):
            b = a + step
            p0 = (c[0] + r * math.cos(a), c[1] + r * math.sin(a))
            p3 = (c[0] + r * math.cos(b), c[1] + r * math.sin(b))
            p1 = (p0[0] - k * r * math.sin(a), p0[1] + k * r * math.cos(a))
            p2 = (p3[0] + k * r * math.sin(b), p3[1] - k * r * math.cos(b))
            self.cmds.append(("C", p1, p2, p3)); self.cur = p3
            a = b
    def close(self): self.cmds.append(("Z",)); self.cur = None
    def points(self): return [cmd[-1] for cmd in self.cmds if cmd[0] != "Z"]
    def signed_area(self):
        p = self.points()
        return sum(p[i][0] * p[(i + 1) % len(p)][1] - p[(i + 1) % len(p)][0] * p[i][1] for i in range(len(p))) / 2

def reverse(c):
    segs, cur, start = [], None, None
    for cmd in c.cmds:
        if cmd[0] == "M": cur = cmd[1]; start = cur
        elif cmd[0] == "L": segs.append(("L", cur, cmd[1])); cur = cmd[1]
        elif cmd[0] == "C": segs.append(("C", cur, cmd[1], cmd[2], cmd[3])); cur = cmd[3]
    if dist(cur, start) > 1e-6: segs.append(("L", cur, start))
    r = Contour(); r.move(segs[-1][-1])
    for seg in reversed(segs):
        if seg[0] == "L": r.line(seg[1])
        else: r.cmds.append(("C", seg[3], seg[2], seg[1])); r.cur = seg[1]
    r.close()
    return r

def solid(c): return reverse(c) if c.signed_area() > 0 else c      # clockwise fills
def hole(c): return reverse(c) if c.signed_area() < 0 else c       # counter-clockwise cuts

A135, A45, Am45, A90, A180 = 3 * math.pi / 4, math.pi / 4, -math.pi / 4, math.pi / 2, math.pi

# ---------- the vane: its outline as two contours, outer and inner ----------
def vane_outer(h):
    c = Contour()
    c.move((-h, F_A[1]))
    c.arc(F_A, RHO + h, A180, A135)                                  # fillet at A
    c.line(add(C, mul(N, R + h)))                                    # upper-left edge
    c.arc(C, R + h, A135, Am45)                                      # the round end
    c.arc(F_B, RHO + h, Am45, -A90)                                  # fillet at B
    c.line((h * 0 + 0.0, -h))                                        # bottom edge back to K
    c.arc(K, h, -A90, -A180)                                         # round join at K (under the shaft)
    c.close()
    return solid(c)

def vane_inner(h):
    c = Contour()
    r = RHO - h
    if r > 0:
        c.move((h, F_A[1]))
        c.arc(F_A, r, A180, A135)
    else:                                                            # sharp: the two inset edges meet
        c.move(meet((h, 0.0), (0.0, 1.0), add(K, mul(N, R - h)), D))
    c.line(add(C, mul(N, R - h)))
    c.arc(C, R - h, A135, Am45)
    if r > 0:
        c.arc(F_B, r, Am45, -A90)
    else:
        c.line(meet((0.0, h), (1.0, 0.0), add(K, mul(N, -(R - h))), D))
    c.line((h, h))                                                   # inner corner at K
    c.close()
    return hole(c)

# ---------- the shaft: nib to the round end's centre; and the barb ----------
def capsule(p, q, h):
    d = (q[0] - p[0], q[1] - p[1]); n = dist(p, q); d = (d[0] / n, d[1] / n)
    left = (-d[1], d[0]); a = math.atan2(left[1], left[0])
    c = Contour()
    c.move(add(p, mul(left, h))); c.line(add(q, mul(left, h)))
    c.arc(q, h, a, a - math.pi)
    c.line(add(p, mul(left, -h)))
    c.arc(p, h, a - math.pi, a - 2 * math.pi)
    c.close()
    return solid(c)

def shaft(h): return capsule(mul(D, -NIB), C, h)

def barb(h):
    y = C[1] - BARB
    on_shaft = meet((0.0, y), (1.0, 0.0), K, D)
    on_edge = meet((0.0, y), (1.0, 0.0), add(K, mul(N, -R)), D)
    return capsule(on_shaft, on_edge, h)

def symbol(s):
    h = s / 2
    return [vane_outer(h), vane_inner(h), shaft(h), barb(h)]

# ---------- centring and emission ----------
def centre():
    pts = [p for c in symbol(8.3) for p in c.points()]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2)
CX, CY = centre()
def world(p): return (p[0] - CX, p[1] - CY)

def fmt(v): return f"{v:.2f}"
def to_svg(contours):
    out = []
    for c in contours:
        for cmd in c.cmds:
            if cmd[0] == "Z": out.append("Z"); continue
            out.append(cmd[0] + " " + " ".join(f"{fmt(x * U)},{fmt(-y * U)}" for x, y in map(world, cmd[1:])))
    return " ".join(out)

def template(name):
    groups = ""
    for wname, s, x in WEIGHTS:
        groups += f'  <g id="{wname}-M" transform="matrix(1 0 0 1 {x} 892.0)">\n   <path d="{to_svg(symbol(s))}" style="fill:black;stroke:none;"/>\n  </g>\n'
    pts = [world(p) for c in symbol(8.3) for p in c.points()]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    left, right = 1575.99 + x0 * U - 4, 1575.99 + x1 * U + 4
    print(f"{name}: regular ink {x1 - x0:.1f} x {y1 - y0:.1f} pt")
    return f'''<?xml version="1.0" encoding="UTF-8"?>
<svg version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="3300" height="2200">
 <!--glyph: "{name}", point size: 100.0, template writer version: "8"-->
 <g id="Notes">
  <rect height="2200" id="artboard" style="fill:white;opacity:1" width="3300" x="0" y="0"/>
  <line id="" style="fill:none;stroke:black;opacity:0.5;stroke-width:0.5;" x1="263" x2="3036" y1="292" y2="292"/>
  <text id="template-version" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;font-weight:bold;" transform="matrix(1 0 0 1 263 322)">Template v.3.0</text>
  <text id="descriptive-name" style="stroke:none;fill:black;font-family:sans-serif;font-size:13px;" transform="matrix(1 0 0 1 263 1953)">{name}</text>
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
  <line id="left-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="{fmt(left)}" x2="{fmt(left)}" y1="600.785" y2="1183.21"/>
  <line id="right-margin" style="fill:none;stroke:#00AEEF;stroke-width:0.5;" x1="{fmt(right)}" x2="{fmt(right)}" y1="600.785" y2="1183.21"/>
 </g>
 <g id="Symbols">
{groups} </g>
</svg>
'''

if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    open(os.path.join(out, "author.svg"), "w").write(template("author"))
