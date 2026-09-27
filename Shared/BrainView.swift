import SwiftUI

// MARK: - Deterministic randomness

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 11) & 0x1FFFFF) / Double(0x1FFFFF)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

// MARK: - Colour helpers (platform independent)

struct RGB {
    var r: Double, g: Double, b: Double
    func mix(_ o: RGB, _ t: Double) -> RGB {
        let k = min(max(t, 0), 1)
        return RGB(r: r + (o.r - r) * k, g: g + (o.g - g) * k, b: b + (o.b - b) * k)
    }
    func darker(_ t: Double) -> RGB { mix(RGB(r: 0.02, g: 0.02, b: 0.03), t) }
    func lighter(_ t: Double) -> RGB { mix(RGB(r: 1, g: 0.97, b: 0.95), t) }
    var color: Color { Color(red: r, green: g, blue: b) }
    func color(_ a: Double) -> Color { Color(red: r, green: g, blue: b, opacity: a) }
}

enum BrainPalette {
    // Healthy cortex: warm pink-beige. Rotten: grey-olive, then dark necrotic.
    static let healthy = RGB(r: 0.93, g: 0.66, b: 0.63)
    static let tired   = RGB(r: 0.86, g: 0.64, b: 0.56)
    static let rotting = RGB(r: 0.62, g: 0.60, b: 0.42)
    static let decayed = RGB(r: 0.43, g: 0.48, b: 0.30)
    static let dead    = RGB(r: 0.27, g: 0.31, b: 0.20)

    static func base(_ rot: Double) -> RGB {
        let t = min(max(rot, 0), 1)
        switch t {
        case ..<0.3:  return healthy.mix(tired, t / 0.3)
        case ..<0.6:  return tired.mix(rotting, (t - 0.3) / 0.3)
        case ..<0.85: return rotting.mix(decayed, (t - 0.6) / 0.25)
        default:      return decayed.mix(dead, (t - 0.85) / 0.15)
        }
    }
}

// MARK: - Geometry of a lateral (side) view brain, normalised to a 1 × 0.8 box

struct BrainGeometry {
    let origin: CGPoint
    let scale: CGFloat

    init(size: CGSize) {
        // Fit a 1.0 × 0.80 box.
        let s = min(size.width, size.height / 0.80)
        scale = s
        origin = CGPoint(x: (size.width - s) / 2, y: (size.height - s * 0.80) / 2)
    }

    func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * scale, y: origin.y + y * scale) }
    func l(_ v: Double) -> CGFloat { v * scale }

    /// Cerebrum silhouette (front = left).
    var cerebrum: Path {
        var path = Path()
        path.move(to: p(0.06, 0.44))
        path.addCurve(to: p(0.26, 0.09), control1: p(0.05, 0.26), control2: p(0.12, 0.12))     // frontal pole up
        path.addCurve(to: p(0.62, 0.05), control1: p(0.36, 0.06), control2: p(0.50, 0.03))     // top
        path.addCurve(to: p(0.95, 0.30), control1: p(0.78, 0.06), control2: p(0.93, 0.14))     // parietal → occipital
        path.addCurve(to: p(0.86, 0.56), control1: p(0.97, 0.42), control2: p(0.94, 0.53))     // occipital pole down
        path.addCurve(to: p(0.62, 0.60), control1: p(0.80, 0.58), control2: p(0.70, 0.58))     // above cerebellum
        path.addCurve(to: p(0.40, 0.69), control1: p(0.56, 0.65), control2: p(0.49, 0.72))     // temporal lobe bottom
        path.addCurve(to: p(0.14, 0.57), control1: p(0.30, 0.67), control2: p(0.17, 0.65))     // temporal pole
        path.addCurve(to: p(0.06, 0.44), control1: p(0.10, 0.54), control2: p(0.06, 0.50))
        path.closeSubpath()
        return path
    }

    var cerebellum: Path {
        var path = Path()
        path.move(to: p(0.64, 0.60))
        path.addCurve(to: p(0.88, 0.60), control1: p(0.70, 0.57), control2: p(0.82, 0.56))
        path.addCurve(to: p(0.80, 0.75), control1: p(0.93, 0.66), control2: p(0.90, 0.74))
        path.addCurve(to: p(0.64, 0.60), control1: p(0.70, 0.76), control2: p(0.62, 0.68))
        path.closeSubpath()
        return path
    }

    var stem: Path {
        var path = Path()
        path.move(to: p(0.58, 0.60))
        path.addCurve(to: p(0.66, 0.60), control1: p(0.60, 0.59), control2: p(0.64, 0.59))
        path.addCurve(to: p(0.63, 0.80), control1: p(0.67, 0.68), control2: p(0.66, 0.76))
        path.addCurve(to: p(0.55, 0.80), control1: p(0.61, 0.82), control2: p(0.57, 0.82))
        path.addCurve(to: p(0.58, 0.60), control1: p(0.54, 0.74), control2: p(0.56, 0.66))
        path.closeSubpath()
        return path
    }

    /// Gyri: worm-like tubes following a regional flow field. Returns centre-line paths.
    func gyri() -> [Path] {
        var rng = SeededRandom(seed: 1337)
        var paths: [Path] = []
        let cg = cerebrum
        // Regional dominant angle (radians). Frontal: tilted back; parietal: arcing; temporal: horizontal; occipital: forward tilt.
        func flow(_ x: Double, _ y: Double) -> Double {
            // Fan pattern radiating from a centre below the Sylvian fissure; real gyri roughly radiate from the insula.
            let cx = 0.46, cy = 0.62
            let a = atan2(y - cy, x - cx)      // angle from centre
            var dir = a + .pi / 2              // tangential (concentric) direction…
            // …blended towards radial in the frontal and occipital lobes
            let radialBlend = x < 0.30 ? 0.55 : (x > 0.72 ? 0.45 : 0.15)
            dir = dir * (1 - radialBlend) + a * radialBlend
            // Temporal lobe: horizontal
            if y > 0.50 && x > 0.16 && x < 0.62 { dir = dir * 0.3 + 0.0 * 0.7 }
            // wiggle
            dir += 0.35 * sin(x * 23 + y * 17) + 0.2 * cos(x * 11 - y * 29)
            return dir
        }
        // Poisson-ish placement on a jittered grid
        let step = 0.064
        var y = 0.06
        while y < 0.72 {
            var x = 0.05
            while x < 0.97 {
                let sx = x + rng.range(-0.02, 0.02), sy = y + rng.range(-0.02, 0.02)
                if cg.contains(p(sx, sy)) {
                    var path = Path()
                    let len = rng.range(0.09, 0.17)
                    let steps = 8
                    let h = len / Double(steps)
                    var px = sx, py = sy
                    path.move(to: p(px, py))
                    let sign: Double = rng.next() < 0.5 ? 1 : -1
                    for i in 0..<steps {
                        let d = flow(px, py) + sign * 0.18 * sin(Double(i) * 0.9 + rng.range(0, 0.4))
                        px += cos(d) * h; py += sin(d) * h
                        path.addLine(to: p(px, py))
                    }
                    paths.append(path)
                }
                x += step
            }
            y += step * 0.92
        }
        return paths
    }

    /// Cerebellum folia: horizontal arcs.
    func folia() -> [Path] {
        var paths: [Path] = []
        for i in 0..<6 {
            let t = 0.60 + Double(i) * 0.026
            var path = Path()
            path.move(to: p(0.64 + Double(i) * 0.008, t + 0.005))
            path.addQuadCurve(to: p(0.90 - Double(i) * 0.012, t + 0.01), control: p(0.77, t - 0.03))
            paths.append(path)
        }
        return paths
    }
}

// MARK: - The brain

/// Lateral-view brain. `rot` 0 = healthy, 1 = fully rotten. `phase` 0…1 drives subtle motion.
struct BrainView: View {
    var rot: Double
    var phase: Double = 0
    var glow: Bool = true

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let rot = min(max(self.rot, 0), 1)
            let g = BrainGeometry(size: size)
            let base = BrainPalette.base(rot)
            let lum = 1 - 0.25 * rot                       // rotten tissue is duller
            let light = base.lighter(0.45 * lum)
            let dark = base.darker(0.40)
            let deep = base.darker(0.65)
            let cerebrum = g.cerebrum, cerebellum = g.cerebellum, stem = g.stem

            // Glow / drop shadow
            if glow {
                ctx.drawLayer { gl in
                    gl.addFilter(.blur(radius: g.l(0.05)))
                    gl.fill(cerebrum, with: .color(base.color(0.35 * lum)))
                    gl.fill(cerebellum, with: .color(base.color(0.25 * lum)))
                }
            }
            ctx.drawLayer { sh in
                sh.addFilter(.blur(radius: g.l(0.02)))
                sh.translateBy(x: 0, y: g.l(0.02))
                sh.fill(cerebrum, with: .color(.black.opacity(0.45)))
                sh.fill(cerebellum, with: .color(.black.opacity(0.45)))
                sh.fill(stem, with: .color(.black.opacity(0.45)))
            }

            // Stem
            ctx.fill(stem, with: .linearGradient(Gradient(colors: [dark.color, deep.color]), startPoint: g.p(0.55, 0.6), endPoint: g.p(0.66, 0.8)))
            ctx.stroke(stem, with: .color(deep.color(0.8)), lineWidth: g.l(0.006))

            // Cerebellum
            ctx.drawLayer { c in
                c.clip(to: cerebellum)
                c.fill(cerebellum, with: .radialGradient(Gradient(colors: [base.mix(light, 0.4).color, dark.color]),
                                                         center: g.p(0.74, 0.62), startRadius: 0, endRadius: g.l(0.2)))
                for f in g.folia() {
                    c.stroke(f, with: .color(deep.color(0.55)), style: StrokeStyle(lineWidth: g.l(0.010), lineCap: .round))
                    c.stroke(f.applying(CGAffineTransform(translationX: 0, y: -g.l(0.008))), with: .color(light.color(0.35)),
                             style: StrokeStyle(lineWidth: g.l(0.005), lineCap: .round))
                }
                // inner shadow
                c.addFilter(.blur(radius: g.l(0.015)))
                c.stroke(cerebellum, with: .color(deep.color(0.9)), lineWidth: g.l(0.03))
            }

            // Cerebrum body
            ctx.drawLayer { b in
                b.clip(to: cerebrum)
                b.fill(cerebrum, with: .radialGradient(
                    Gradient(stops: [.init(color: light.color, location: 0), .init(color: base.color, location: 0.55), .init(color: dark.color, location: 1)]),
                    center: g.p(0.36, 0.24), startRadius: 0, endRadius: g.l(0.75)))

                // Gyri as tubes: shadow, body, highlight
                let tubes = g.gyri()
                let w = g.l(0.052)
                for t in tubes {
                    b.stroke(t.applying(CGAffineTransform(translationX: g.l(0.004), y: g.l(0.010))),
                             with: .color(deep.color(0.55)), style: StrokeStyle(lineWidth: w * 1.05, lineCap: .round, lineJoin: .round))
                }
                for t in tubes {
                    b.stroke(t, with: .color(base.mix(light, 0.12).color), style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
                }
                for t in tubes {
                    b.stroke(t.applying(CGAffineTransform(translationX: -g.l(0.003), y: -g.l(0.009))),
                             with: .color(light.color(0.55 * lum)), style: StrokeStyle(lineWidth: w * 0.38, lineCap: .round, lineJoin: .round))
                }

                // Sylvian fissure & central sulcus (deeper dark lines)
                var fiss = Path()
                fiss.move(to: g.p(0.15, 0.51)); fiss.addCurve(to: g.p(0.58, 0.40), control1: g.p(0.30, 0.53), control2: g.p(0.46, 0.42))
                var central = Path()
                central.move(to: g.p(0.50, 0.07)); central.addCurve(to: g.p(0.43, 0.38), control1: g.p(0.52, 0.18), control2: g.p(0.40, 0.26))
                b.drawLayer { f in
                    f.addFilter(.blur(radius: g.l(0.006)))
                    f.stroke(fiss, with: .color(deep.color(0.75)), style: StrokeStyle(lineWidth: g.l(0.012), lineCap: .round))
                    f.stroke(central, with: .color(deep.color(0.6)), style: StrokeStyle(lineWidth: g.l(0.009), lineCap: .round))
                }

                // Rot: necrotic patches (soft), growing with rot
                if rot > 0.12 {
                    var rng = SeededRandom(seed: 99)
                    let n = Int(rot * 22)
                    b.drawLayer { r in
                        r.addFilter(.blur(radius: g.l(0.012)))
                        for i in 0..<n {
                            let x = rng.range(0.10, 0.92), y = rng.range(0.10, 0.64)
                            let rad = rng.range(0.03, 0.075) * (0.7 + 0.5 * rot)
                            var s = Path()
                            s.addEllipse(in: CGRect(x: g.origin.x + (x - rad) * g.scale, y: g.origin.y + (y - rad * 0.8) * g.scale,
                                                    width: g.l(rad * 2), height: g.l(rad * 1.6)))
                            let necro = RGB(r: 0.20, g: 0.22, b: 0.12).mix(deep, 0.4)
                            r.fill(s, with: .color(necro.color(0.30 + 0.55 * rot)))
                            if i % 2 == 0 {
                                var core = Path()
                                core.addEllipse(in: CGRect(x: g.origin.x + (x - rad * 0.45) * g.scale, y: g.origin.y + (y - rad * 0.35) * g.scale,
                                                           width: g.l(rad * 0.9), height: g.l(rad * 0.7)))
                                r.fill(core, with: .color(Color.black.opacity(0.35 * rot)))
                            }
                        }
                    }
                }

                // Veins appear mid-rot
                if rot > 0.35 {
                    var rng = SeededRandom(seed: 7)
                    var veins = Path()
                    for _ in 0..<6 {
                        var x = rng.range(0.15, 0.85), y = rng.range(0.12, 0.58)
                        veins.move(to: g.p(x, y))
                        for _ in 0..<3 {
                            let cx = x + rng.range(-0.06, 0.06), cy = y + rng.range(-0.05, 0.05)
                            x += rng.range(-0.07, 0.07); y += rng.range(-0.04, 0.07)
                            veins.addQuadCurve(to: g.p(x, y), control: g.p(cx, cy))
                        }
                    }
                    b.stroke(veins, with: .color(RGB(r: 0.30, g: 0.10, b: 0.20).color((rot - 0.35) * 0.4)),
                             style: StrokeStyle(lineWidth: g.l(0.004), lineCap: .round, lineJoin: .round))
                }

                // Mould: pale fuzzy colonies at heavy rot
                if rot > 0.7 {
                    var rng = SeededRandom(seed: 555)
                    let k = (rot - 0.7) / 0.3
                    b.drawLayer { m in
                        m.addFilter(.blur(radius: g.l(0.008)))
                        for _ in 0..<Int(6 + 10 * k) {
                            let x = rng.range(0.12, 0.90), y = rng.range(0.10, 0.62)
                            let rad = rng.range(0.012, 0.03)
                            var s = Path()
                            s.addEllipse(in: CGRect(x: g.origin.x + (x - rad) * g.scale, y: g.origin.y + (y - rad) * g.scale, width: g.l(rad * 2), height: g.l(rad * 2)))
                            m.fill(s, with: .color(RGB(r: 0.78, g: 0.84, b: 0.62).color(0.25 + 0.35 * k)))
                        }
                    }
                }
                // Global darkening veil as tissue dies
                if rot > 0.5 {
                    b.fill(cerebrum, with: .color(Color.black.opacity(0.22 * (rot - 0.5) / 0.5)))
                }

                // Inner shadow along the edge for volume
                b.drawLayer { e in
                    e.addFilter(.blur(radius: g.l(0.025)))
                    e.stroke(cerebrum, with: .color(deep.color(0.9)), lineWidth: g.l(0.05))
                }
                // Specular sheen (slimy when rotten)
                var sheen = Path()
                sheen.addEllipse(in: CGRect(origin: g.p(0.22, 0.11), size: CGSize(width: g.l(0.30), height: g.l(0.13))))
                b.drawLayer { s in
                    s.addFilter(.blur(radius: g.l(0.03)))
                    s.fill(sheen, with: .color(.white.opacity(0.18 + 0.10 * rot)))
                }
            }

            // Outline
            ctx.stroke(cerebrum, with: .color(deep.color(0.9)), lineWidth: g.l(0.006))
            ctx.stroke(cerebellum, with: .color(deep.color(0.9)), lineWidth: g.l(0.006))


            // Critters: flies circling from mid-rot, beetles crawling and maggots in the necrotic patches at heavy rot.
            if rot > 0.5 {
                let k = (rot - 0.5) / 0.5
                let ink = RGB(r: 0.09, g: 0.09, b: 0.07)
                var rng = SeededRandom(seed: 4242)

                // Flies: hover around the silhouette on small orbits driven by `phase`.
                let flyCount = Int(2 + 6 * k)
                for i in 0..<flyCount {
                    let ax = rng.range(0.02, 0.98), ay = rng.range(0.02, 0.70)
                    let orbit = rng.range(0.015, 0.035)
                    let speed = rng.range(1.0, 2.2) * (rng.next() < 0.5 ? 1 : -1)
                    let a = phase * 2 * .pi * speed + Double(i) * 1.7
                    let x = ax + cos(a) * orbit, y = ay + sin(a * 1.3) * orbit * 0.6
                    let sz = rng.range(0.024, 0.034)
                    let c = g.p(x, y)
                    // wings (translucent, slightly ahead of the body)
                    let flap = 0.6 + 0.4 * abs(sin(a * 9))
                    for side in [-1.0, 1.0] {
                        var w = Path()
                        w.addEllipse(in: CGRect(x: c.x + side * g.l(sz * 0.15) - g.l(sz * 0.55), y: c.y - g.l(sz * 0.9 * flap),
                                                width: g.l(sz * 1.1), height: g.l(sz * 0.7 * flap)))
                        ctx.fill(w.applying(CGAffineTransform(translationX: c.x, y: c.y).rotated(by: side * 0.55).translatedBy(x: -c.x, y: -c.y)),
                                 with: .color(.white.opacity(0.35)))
                    }
                    var body = Path()
                    body.addEllipse(in: CGRect(x: c.x - g.l(sz * 0.5), y: c.y - g.l(sz * 0.32), width: g.l(sz), height: g.l(sz * 0.64)))
                    ctx.fill(body, with: .color(ink.color(0.9)))
                    var head = Path()
                    head.addEllipse(in: CGRect(x: c.x + g.l(sz * 0.35), y: c.y - g.l(sz * 0.22), width: g.l(sz * 0.42), height: g.l(sz * 0.42)))
                    ctx.fill(head, with: .color(ink.color(0.95)))
                    var eye = Path()
                    eye.addEllipse(in: CGRect(x: c.x + g.l(sz * 0.5), y: c.y - g.l(sz * 0.16), width: g.l(sz * 0.16), height: g.l(sz * 0.16)))
                    ctx.fill(eye, with: .color(RGB(r: 0.75, g: 0.15, b: 0.12).color(0.9)))
                }

                // Beetles: crawl slowly along the surface (inside the silhouette).
                if rot > 0.65 {
                    let kb = (rot - 0.65) / 0.35
                    let beetleCount = Int(1 + 3 * kb)
                    var placed = 0, tries = 0
                    while placed < beetleCount && tries < 40 {
                        tries += 1
                        let bx = rng.range(0.10, 0.90), by = rng.range(0.10, 0.62)
                        let dir = rng.range(0, 2 * .pi)
                        let crawl = 0.012 * sin(phase * 2 * .pi + Double(placed) * 2.1)
                        let x = bx + cos(dir) * crawl, y = by + sin(dir) * crawl
                        guard cerebrum.contains(g.p(x, y)) else { continue }
                        placed += 1
                        let sz = rng.range(0.03, 0.042)
                        let c = g.p(x, y)
                        let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: dir).translatedBy(x: -c.x, y: -c.y)
                        // legs
                        var legs = Path()
                        for j in -1...1 {
                            let ly = c.y + CGFloat(j) * g.l(sz * 0.22)
                            legs.move(to: CGPoint(x: c.x - g.l(sz * 0.62), y: ly)); legs.addLine(to: CGPoint(x: c.x - g.l(sz * 0.30), y: ly))
                            legs.move(to: CGPoint(x: c.x + g.l(sz * 0.62), y: ly)); legs.addLine(to: CGPoint(x: c.x + g.l(sz * 0.30), y: ly))
                        }
                        ctx.stroke(legs.applying(t), with: .color(ink.color(0.85)), style: StrokeStyle(lineWidth: g.l(0.0035), lineCap: .round))
                        // shell
                        var shell = Path()
                        shell.addEllipse(in: CGRect(x: c.x - g.l(sz * 0.32), y: c.y - g.l(sz * 0.5), width: g.l(sz * 0.64), height: g.l(sz)))
                        ctx.fill(shell.applying(t), with: .color(RGB(r: 0.16, g: 0.14, b: 0.10).color(0.95)))
                        var sheen = Path()
                        sheen.addEllipse(in: CGRect(x: c.x - g.l(sz * 0.18), y: c.y - g.l(sz * 0.38), width: g.l(sz * 0.22), height: g.l(sz * 0.4)))
                        ctx.fill(sheen.applying(t), with: .color(RGB(r: 0.35, g: 0.42, b: 0.28).color(0.5)))
                        var seam = Path()
                        seam.move(to: CGPoint(x: c.x, y: c.y - g.l(sz * 0.45))); seam.addLine(to: CGPoint(x: c.x, y: c.y + g.l(sz * 0.45)))
                        ctx.stroke(seam.applying(t), with: .color(ink.color(0.7)), lineWidth: g.l(0.003))
                        var bhead = Path()
                        bhead.addEllipse(in: CGRect(x: c.x - g.l(sz * 0.16), y: c.y - g.l(sz * 0.66), width: g.l(sz * 0.32), height: g.l(sz * 0.3)))
                        ctx.fill(bhead.applying(t), with: .color(ink.color(0.95)))
                    }
                }

                // Maggots: pale segmented grubs wriggling in the tissue at heavy rot.
                if rot > 0.78 {
                    let km = (rot - 0.78) / 0.22
                    let count = Int(3 + 7 * km)
                    var placed = 0, tries = 0
                    while placed < count && tries < 60 {
                        tries += 1
                        let mx = rng.range(0.12, 0.88), my = rng.range(0.12, 0.62)
                        guard cerebrum.contains(g.p(mx, my)) else { continue }
                        placed += 1
                        let len = rng.range(0.035, 0.055), w = rng.range(0.010, 0.014)
                        let dir = rng.range(0, 2 * .pi)
                        let wig = 0.25 * sin(phase * 4 * .pi + Double(placed) * 1.3)
                        var m = Path()
                        m.move(to: g.p(mx, my))
                        m.addQuadCurve(to: g.p(mx + cos(dir) * len, my + sin(dir) * len),
                                       control: g.p(mx + cos(dir + wig + 0.9) * len * 0.5, my + sin(dir + wig + 0.9) * len * 0.5))
                        ctx.stroke(m, with: .color(RGB(r: 0.12, g: 0.12, b: 0.08).color(0.5)), style: StrokeStyle(lineWidth: g.l(w * 1.4), lineCap: .round))
                        ctx.stroke(m, with: .color(RGB(r: 0.93, g: 0.90, b: 0.78).color(0.95)), style: StrokeStyle(lineWidth: g.l(w), lineCap: .round))
                        // segments
                        ctx.stroke(m, with: .color(RGB(r: 0.72, g: 0.68, b: 0.52).color(0.8)),
                                   style: StrokeStyle(lineWidth: g.l(w * 0.9), lineCap: .butt, dash: [g.l(0.004), g.l(0.008)]))
                        var hd = Path()
                        let e = g.p(mx + cos(dir) * len, my + sin(dir) * len)
                        hd.addEllipse(in: CGRect(x: e.x - g.l(0.003), y: e.y - g.l(0.003), width: g.l(0.006), height: g.l(0.006)))
                        ctx.fill(hd, with: .color(RGB(r: 0.35, g: 0.25, b: 0.15).color))
                    }
                }
            }

            // Drips at heavy rot (subtle)
            if rot > 0.65 {
                let k = (rot - 0.65) / 0.35
                var rng = SeededRandom(seed: 3)
                for i in 0..<3 {
                    let x = rng.range(0.20, 0.52)
                    let len = rng.range(0.04, 0.10) * k + 0.01 * sin(phase * 2 * .pi + Double(i))
                    let w = rng.range(0.012, 0.02)
                    var d = Path()
                    d.addRoundedRect(in: CGRect(x: g.origin.x + (x - w / 2) * g.scale, y: g.origin.y + 0.62 * g.scale, width: g.l(w), height: g.l(0.06 + len)),
                                     cornerSize: CGSize(width: g.l(w / 2), height: g.l(w / 2)))
                    ctx.fill(d, with: .color(base.darker(0.25).color))
                }
            }
        }
    }
}

/// Brain that breathes gently. Use in the app; widgets use the static BrainView.
struct AnimatedBrainView: View {
    var rot: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            BrainView(rot: rot, phase: (t / 6.0).truncatingRemainder(dividingBy: 1))
                .scaleEffect(1 + 0.012 * sin(t * 1.1))
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        VStack {
            HStack { BrainView(rot: 0).frame(width: 120, height: 100); BrainView(rot: 0.5).frame(width: 120, height: 100); BrainView(rot: 1).frame(width: 120, height: 100) }
            AnimatedBrainView(rot: 0.3).frame(width: 340, height: 280)
        }
    }
}
