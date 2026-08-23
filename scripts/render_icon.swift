// App icon: the lateral brain from BrainView on a soft dark gradient. Run: swift scripts/render_icon.swift <outdir>
// (Concatenated with Shared/BrainView.swift by scripts/make_icon.sh.)
import SwiftUI
import AppKit

struct IconView: View {
    var tinted = false
    var body: some View {
        ZStack {
            if tinted {
                Color.clear
            } else {
                LinearGradient(colors: [Color(red: 0.14, green: 0.13, blue: 0.17), Color(red: 0.05, green: 0.05, blue: 0.07)],
                               startPoint: .top, endPoint: .bottom)
                RadialGradient(colors: [Color(red: 0.93, green: 0.66, blue: 0.63).opacity(0.22), .clear],
                               center: .center, startRadius: 0, endRadius: 560)
            }
            BrainView(rot: 0.02, glow: !tinted)
                .frame(width: 820, height: 700)
                .offset(y: 10)
                .if(tinted) { $0.colorMultiply(.white).saturation(0).brightness(0.25) }
        }
        .frame(width: 1024, height: 1024)
    }
}

extension View {
    @ViewBuilder func `if`<T: View>(_ c: Bool, _ t: (Self) -> T) -> some View { if c { t(self) } else { self } }
}

@MainActor func write<V: View>(_ v: V, _ path: String) {
    let r = ImageRenderer(content: v); r.scale = 1
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: path)); print("wrote \(path)")
    }
}
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
MainActor.assumeIsolated {
    write(IconView(), "\(out)/icon-1024.png")
    write(IconView(), "\(out)/icon-1024-dark.png")
    write(IconView(tinted: true), "\(out)/icon-1024-tinted.png")
}
