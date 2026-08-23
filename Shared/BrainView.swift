import SwiftUI

/// Deterministic pseudo-random generator so the rot pattern is stable between renders.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double((state >> 11) & 0x1FFFFF) / Double(0x1FFFFF)
    }
    mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

/// The brain. `rot` 0 = pink and crisp, 1 = green, dripping, flies.
/// `phase` (0...1, looping) drives subtle motion when animated.
struct BrainView: View {
    var rot: Double
    var phase: Double = 0
    var glow: Bool = true

    var body: some View {
        Canvas(rendersAsynchronously: false) { ctx, size in
            let rot = min(max(rot, 0), 1)
            // Leave room below for drips and stem.
            let side = min(size.width, size.height * 1.1)
            let origin = CGPoint(x: (size.width - side) / 2, y: (size.height - side * 0.92) / 2 - side * 0.04)
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: origin.x + x * side, y: origin.y + y * side) }
            func L(_ v: Double) -> CGFloat { v * side }

            let base = Theme.rotColor(rot)
            let dark = base.mix(with: .black, by: 0.38)
            let light = base.mix(with: .white, by: 0.22)
            let spot = Color(red: 0.22, green: 0.33, blue: 0.11).mix(with: dark, by: 0.3)

            // Silhouette: union of lumps.
            var brain = Path()
            let lumps: [(Double, Double, Double)] = [
                (0.30, 0.40, 0.21), (0.50, 0.30, 0.23), (0.70, 0.40, 0.21),
                (0.24, 0.57, 0.19), (0.76, 0.57, 0.19),
                (0.40, 0.64, 0.21), (0.60, 0.64, 0.21), (0.50, 0.52, 0.27)
            ]
            for l in lumps {
                let wob = 1 + 0.012 * sin(phase * 2 * .pi + l.0 * 9)
                brain.addEllipse(in: CGRect(x: origin.x + (l.0 - l.2 * wob) * side,
                                            y: origin.y + (l.1 - l.2 * wob) * side,
                                            width: l.2 * 2 * wob * side, height: l.2 * 2 * wob * side))
            }
            // Stem
            var stem = Path()
            stem.addRoundedRect(in: CGRect(origin: P(0.52, 0.74), size: CGSize(width: L(0.14), height: L(0.14))),
                                cornerSize: CGSize(width: L(0.05), height: L(0.05)))
            stem = stem.applying(CGAffineTransform(translationX: 0, y: 0).rotated(by: 0))

            // Glow
            if glow {
                ctx.drawLayer { g in
                    g.addFilter(.blur(radius: L(0.06)))
                    g.fill(brain, with: .color(base.opacity(0.45)))
                }
            }

            // Drips (behind brain so their roots hide under the lumps)
            if rot > 0.5 {
                let strength = (rot - 0.5) / 0.5
                var rng = SeededRandom(seed: 7)
                let dripCount = 2 + Int(strength * 3)
                for i in 0..<dripCount {
                    let x = rng.range(0.24, 0.76)
                    let len = rng.range(0.08, 0.22) * strength + 0.03 * sin(phase * 2 * .pi + Double(i))
                    let w = rng.range(0.035, 0.06)
                    var drip = Path()
                    drip.addRoundedRect(in: CGRect(x: origin.x + (x - w / 2) * side, y: origin.y + 0.70 * side,
                                                   width: L(w), height: L(0.12 + len)),
                                        cornerSize: CGSize(width: L(w / 2), height: L(w / 2)))
                    drip.addEllipse(in: CGRect(x: origin.x + (x - w * 0.65) * side,
                                               y: origin.y + (0.80 + len) * side,
                                               width: L(w * 1.3), height: L(w * 1.3)))
                    ctx.fill(drip, with: .color(dark.mix(with: Theme.slime, by: 0.35)))
                }
            }

            // Stem
            ctx.fill(stem, with: .color(dark))

            // Dark underlay = outline (stroking the union would show inner lump edges)
            let outline = brain.applying(CGAffineTransform(translationX: origin.x + side / 2, y: origin.y + side / 2)
                .scaledBy(x: 1.035, y: 1.035).translatedBy(x: -(origin.x + side / 2), y: -(origin.y + side / 2)))
            ctx.fill(outline, with: .color(dark.mix(with: .black, by: 0.5)))

            // Brain body
            ctx.fill(brain, with: .radialGradient(
                Gradient(colors: [light, base, dark]),
                center: P(0.40, 0.38), startRadius: 0, endRadius: L(0.62)))

            // Everything inside the silhouette
            ctx.drawLayer { inner in
                inner.clip(to: brain)

                // Gyri squiggles
                var gyri = Path()
                let curves: [[(Double, Double)]] = [
                    [(0.16, 0.50), (0.22, 0.30), (0.34, 0.42), (0.30, 0.60)],
                    [(0.28, 0.26), (0.36, 0.18), (0.46, 0.30), (0.40, 0.46)],
                    [(0.20, 0.66), (0.34, 0.56), (0.44, 0.70), (0.38, 0.80)],
                    [(0.84, 0.50), (0.78, 0.30), (0.66, 0.42), (0.70, 0.60)],
                    [(0.72, 0.26), (0.64, 0.18), (0.54, 0.30), (0.60, 0.46)],
                    [(0.80, 0.66), (0.66, 0.56), (0.56, 0.70), (0.62, 0.80)],
                    [(0.40, 0.52), (0.30, 0.46), (0.36, 0.36), (0.46, 0.40)],
                    [(0.60, 0.52), (0.70, 0.46), (0.64, 0.36), (0.54, 0.40)]
                ]
                for c in curves {
                    gyri.move(to: P(c[0].0, c[0].1))
                    gyri.addCurve(to: P(c[3].0, c[3].1), control1: P(c[1].0, c[1].1), control2: P(c[2].0, c[2].1))
                }
                inner.stroke(gyri, with: .color(dark.opacity(0.45)), style: StrokeStyle(lineWidth: L(0.022), lineCap: .round))
                inner.stroke(gyri, with: .color(light.opacity(0.35)),
                             style: StrokeStyle(lineWidth: L(0.008), lineCap: .round))

                // Central fissure
                var fissure = Path()
                fissure.move(to: P(0.50, 0.08))
                fissure.addCurve(to: P(0.50, 0.74), control1: P(0.56, 0.30), control2: P(0.44, 0.52))
                inner.stroke(fissure, with: .color(dark.opacity(0.8)), style: StrokeStyle(lineWidth: L(0.035), lineCap: .round))

                // Rot spots
                if rot > 0.08 {
                    var rng = SeededRandom(seed: 42)
                    let count = Int(rot * 16)
                    for i in 0..<count {
                        let x = rng.range(0.12, 0.88), y = rng.range(0.16, 0.80)
                        let r = rng.range(0.025, 0.07) * (0.6 + 0.4 * rot)
                        let a = 0.35 + 0.5 * rot
                        var s = Path()
                        s.addEllipse(in: CGRect(x: origin.x + (x - r) * side, y: origin.y + (y - r * 0.85) * side,
                                                width: L(r * 2), height: L(r * 1.7)))
                        inner.fill(s, with: .color(spot.opacity(a)))
                        if i % 3 == 0 {
                            var core = Path()
                            core.addEllipse(in: CGRect(x: origin.x + (x - r * 0.4) * side, y: origin.y + (y - r * 0.35) * side,
                                                       width: L(r * 0.8), height: L(r * 0.7)))
                            inner.fill(core, with: .color(Color.black.opacity(0.25 * rot)))
                        }
                    }
                }

                // Cracks
                if rot > 0.7 {
                    var crack = Path()
                    crack.move(to: P(0.30, 0.34)); crack.addLine(to: P(0.36, 0.44)); crack.addLine(to: P(0.33, 0.52)); crack.addLine(to: P(0.40, 0.60))
                    crack.move(to: P(0.72, 0.30)); crack.addLine(to: P(0.66, 0.40)); crack.addLine(to: P(0.70, 0.50))
                    inner.stroke(crack, with: .color(Color.black.opacity(0.45 * (rot - 0.7) / 0.3)),
                                 style: StrokeStyle(lineWidth: L(0.012), lineCap: .round, lineJoin: .round))
                }

                // Highlight
                var hl = Path()
                hl.addEllipse(in: CGRect(origin: P(0.30, 0.16), size: CGSize(width: L(0.18), height: L(0.10))))
                inner.fill(hl, with: .color(.white.opacity(0.18 * (1 - rot * 0.7))))
            }


            // Flies
            if rot > 0.8 {
                let n = rot > 0.95 ? 3 : 2
                for i in 0..<n {
                    let t = phase * 2 * .pi + Double(i) * 2.1
                    let cx = 0.5 + 0.46 * cos(t * (i == 0 ? 1 : -1.3)), cy = 0.30 + 0.18 * sin(t * 1.7)
                    var fly = Path()
                    fly.addEllipse(in: CGRect(x: origin.x + (cx - 0.016) * side, y: origin.y + (cy - 0.012) * side,
                                              width: L(0.032), height: L(0.024)))
                    ctx.fill(fly, with: .color(.black.opacity(0.85)))
                    var wings = Path()
                    wings.addEllipse(in: CGRect(x: origin.x + (cx - 0.03) * side, y: origin.y + (cy - 0.03) * side,
                                                width: L(0.028), height: L(0.016)))
                    wings.addEllipse(in: CGRect(x: origin.x + (cx + 0.002) * side, y: origin.y + (cy - 0.03) * side,
                                                width: L(0.028), height: L(0.016)))
                    ctx.fill(wings, with: .color(.white.opacity(0.5)))
                }
            }
        }
    }
}

extension Color {
    /// Linear RGB mix (approximate, good enough for UI tints).
    func mix(with other: Color, by t: Double) -> Color {
        let a = UIColor(self).rgba, b = UIColor(other).rgba
        let k = min(max(t, 0), 1)
        return Color(red: a.r + (b.r - a.r) * k, green: a.g + (b.g - a.g) * k,
                     blue: a.b + (b.b - a.b) * k, opacity: a.a + (b.a - a.a) * k)
    }
}

extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}

/// Brain that gently breathes and drips. Use in the app; widgets use the static BrainView.
struct AnimatedBrainView: View {
    var rot: Double
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            let phase = (t / 6.0).truncatingRemainder(dividingBy: 1)
            BrainView(rot: rot, phase: phase)
                .scaleEffect(1 + 0.015 * sin(t * 1.2))
        }
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack {
            HStack { BrainView(rot: 0).frame(width: 110, height: 110); BrainView(rot: 0.4).frame(width: 110, height: 110); BrainView(rot: 1).frame(width: 110, height: 110) }
            AnimatedBrainView(rot: 0.75).frame(width: 300, height: 300)
        }
    }
}
