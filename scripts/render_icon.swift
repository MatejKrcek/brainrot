import AppKit

// Renders the app icon: a half-fresh / half-rotting brain on a dark ground.
func brainPath(in r: CGRect) -> NSBezierPath {
    let p = NSBezierPath()
    let side = r.width
    let lumps: [(CGFloat, CGFloat, CGFloat)] = [
        (0.30, 0.40, 0.21), (0.50, 0.30, 0.23), (0.70, 0.40, 0.21),
        (0.24, 0.57, 0.19), (0.76, 0.57, 0.19),
        (0.40, 0.64, 0.21), (0.60, 0.64, 0.21), (0.50, 0.52, 0.27)]
    for l in lumps {
        // AppKit is y-up; flip y.
        let rect = CGRect(x: r.minX + (l.0 - l.2) * side, y: r.minY + (1 - l.1 - l.2) * side, width: l.2 * 2 * side, height: l.2 * 2 * side)
        p.append(NSBezierPath(ovalIn: rect))
    }
    p.windingRule = .nonZero
    return p
}

func render(size: CGFloat, dark: Bool, tinted: Bool, to path: String) {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    if tinted {
        // Tinted icons: white-on-transparent with alpha = shape; iOS tints it.
        NSColor.clear.setFill(); rect.fill()
    } else {
        let bg = NSGradient(colors: [NSColor(red: 0.10, green: 0.09, blue: 0.16, alpha: 1),
                                     NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)])!
        bg.draw(in: rect, angle: -90)
        // Subtle acid ring glow
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: size * 0.08, color: NSColor(red: 0.78, green: 1, blue: 0.24, alpha: 0.35).cgColor)
        NSColor(red: 0.78, green: 1, blue: 0.24, alpha: 0.0).setFill()
        NSBezierPath(ovalIn: rect.insetBy(dx: size * 0.18, dy: size * 0.18)).fill()
        ctx.restoreGState()
    }

    let brainRect = rect.insetBy(dx: size * 0.13, dy: size * 0.13).offsetBy(dx: 0, dy: size * 0.02)
    let brain = brainPath(in: brainRect)
    if !tinted {
        // Dark underlay acts as the outline.
        NSColor(red: 0.12, green: 0.08, blue: 0.12, alpha: 1).setFill()
        brainPath(in: brainRect.insetBy(dx: -size * 0.012, dy: -size * 0.012)).fill()
    }

    // Fill: left half pink, right half rotting green, blended.
    ctx.saveGState()
    brain.addClip()
    let pink = NSColor(red: 1.0, green: 0.42, blue: 0.62, alpha: 1)
    let green = NSColor(red: 0.38, green: 0.58, blue: 0.20, alpha: 1)
    if tinted {
        NSColor.white.setFill(); rect.fill()
    } else {
        let grad = NSGradient(colorsAndLocations: (pink, 0.0), (pink, 0.42), (NSColor(red: 0.74, green: 0.66, blue: 0.30, alpha: 1), 0.55), (green, 0.68), (green, 1.0))!
        grad.draw(in: brainRect, angle: 0)
        // Light from top-left
        let hl = NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0.0)])!
        hl.draw(in: brainRect, angle: -60)
        // Rot spots on right side
        srand48(42)
        for _ in 0..<16 {
            let x = brainRect.minX + brainRect.width * (0.52 + 0.40 * CGFloat(drand48()))
            let y = brainRect.minY + brainRect.height * (0.18 + 0.64 * CGFloat(drand48()))
            let r = brainRect.width * (0.025 + 0.05 * CGFloat(drand48()))
            NSColor(red: 0.2, green: 0.3, blue: 0.1, alpha: 0.65).setFill()
            NSBezierPath(ovalIn: CGRect(x: x - r, y: y - r * 0.85, width: r * 2, height: r * 1.7)).fill()
        }
        // Gyri
        let dark = NSColor.black.withAlphaComponent(0.18)
        dark.setStroke()
        let curves: [[(CGFloat, CGFloat)]] = [
            [(0.16, 0.50), (0.22, 0.30), (0.34, 0.42), (0.30, 0.60)],
            [(0.28, 0.26), (0.36, 0.18), (0.46, 0.30), (0.40, 0.46)],
            [(0.20, 0.66), (0.34, 0.56), (0.44, 0.70), (0.38, 0.80)],
            [(0.84, 0.50), (0.78, 0.30), (0.66, 0.42), (0.70, 0.60)],
            [(0.72, 0.26), (0.64, 0.18), (0.54, 0.30), (0.60, 0.46)],
            [(0.80, 0.66), (0.66, 0.56), (0.56, 0.70), (0.62, 0.80)],
            [(0.40, 0.52), (0.30, 0.46), (0.36, 0.36), (0.46, 0.40)],
            [(0.60, 0.52), (0.70, 0.46), (0.64, 0.36), (0.54, 0.40)]]
        func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: brainRect.minX + x * brainRect.width, y: brainRect.minY + (1 - y) * brainRect.height) }
        for c in curves {
            let bp = NSBezierPath(); bp.lineWidth = size * 0.016; bp.lineCapStyle = .round
            bp.move(to: P(c[0].0, c[0].1)); bp.curve(to: P(c[3].0, c[3].1), controlPoint1: P(c[1].0, c[1].1), controlPoint2: P(c[2].0, c[2].1))
            bp.stroke()
        }
        let f = NSBezierPath(); f.lineWidth = size * 0.03; f.lineCapStyle = .round
        f.move(to: P(0.5, 0.08)); f.curve(to: P(0.5, 0.74), controlPoint1: P(0.56, 0.30), controlPoint2: P(0.44, 0.52))
        NSColor.black.withAlphaComponent(0.45).setStroke(); f.stroke()
    }
    ctx.restoreGState()

    // Drips on the rotten side
    if !tinted {
        green.blended(withFraction: 0.3, of: .black)!.setFill()
        for (x, len) in [(0.62, 0.12), (0.72, 0.20), (0.80, 0.08)] as [(CGFloat, CGFloat)] {
            let w = size * 0.05
            let top = brainRect.minY + brainRect.height * 0.30
            let drip = NSBezierPath(roundedRect: CGRect(x: brainRect.minX + brainRect.width * x - w / 2, y: top - brainRect.height * len, width: w, height: brainRect.height * len + w), xRadius: w / 2, yRadius: w / 2)
            drip.fill()
        }
    } else {
        NSColor.white.setFill()
        for (x, len) in [(0.62, 0.12), (0.72, 0.20), (0.80, 0.08)] as [(CGFloat, CGFloat)] {
            let w = size * 0.05
            let top = brainRect.minY + brainRect.height * 0.30
            NSBezierPath(roundedRect: CGRect(x: brainRect.minX + brainRect.width * x - w / 2, y: top - brainRect.height * len, width: w, height: brainRect.height * len + w), xRadius: w / 2, yRadius: w / 2).fill()
        }
    }


    img.unlockFocus()
    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
render(size: 1024, dark: false, tinted: false, to: "\(out)/icon-1024.png")
render(size: 1024, dark: true, tinted: false, to: "\(out)/icon-1024-dark.png")
render(size: 1024, dark: false, tinted: true, to: "\(out)/icon-1024-tinted.png")
