// Renders BrainView at several rot levels to PNG (macOS, for quick iteration).
// usage: swift scripts/preview_brain.swift out.png
import SwiftUI
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "brain_preview.png"
struct Sheet: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ForEach([0.0, 0.25, 0.5], id: \.self) { r in BrainView(rot: r).frame(width: 300, height: 240) }
            }
            HStack(spacing: 16) {
                ForEach([0.75, 0.9, 1.0], id: \.self) { r in BrainView(rot: r).frame(width: 300, height: 240) }
            }
        }
        .padding(24)
        .background(Color(red: 0.043, green: 0.043, blue: 0.063))
    }
}
@MainActor func render() {
    let renderer = ImageRenderer(content: Sheet())
    renderer.scale = 2
    if let img = renderer.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out)); print("wrote \(out)")
    } else { print("render failed") }
}
MainActor.assumeIsolated { render() }
