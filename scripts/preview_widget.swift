// Renders the Home Screen sizes of the Brain health widget at several health levels to a PNG (macOS; Lock Screen families are iOS-only).
// usage: scripts/preview_widget.sh out.png   (concatenates the needed sources; see the .sh)
import SwiftUI
import AppKit
import WidgetKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "widget_preview.png"
let dark = CommandLine.arguments.contains("dark")
func snap(_ m: Int) -> RotSnapshot { RotSnapshot(minutes: m, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: true) }
struct Tile<C: View>: View {
    let w: CGFloat, h: CGFloat
    var rot: Double = 0
    @ViewBuilder var content: C
    var body: some View {
        content.frame(width: w, height: h)
            .background {
                ZStack {
                    dark ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
                    RadialGradient(colors: [Theme.rotColor(rot).opacity(0.22), .clear],
                                   center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 190)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
    }
}
struct Sheet: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                ForEach([0, 20, 40, 60], id: \.self) { m in Tile(w: 158, h: 158, rot: snap(m).rot) { HealthWidgetContent(snap: snap(m), family: .systemSmall) } }
            }
            HStack(spacing: 16) {
                Tile(w: 338, h: 158, rot: snap(25).rot) { HealthWidgetContent(snap: snap(25), family: .systemMedium) }
                Tile(w: 338, h: 158, rot: snap(70).rot) { HealthWidgetContent(snap: snap(70), family: .systemMedium) }
            }
            HStack(spacing: 16) {
                Tile(w: 338, h: 354, rot: snap(35).rot) { HealthWidgetContent(snap: snap(35), family: .systemLarge) }
                Tile(w: 338, h: 354, rot: snap(80).rot) { HealthWidgetContent(snap: snap(80), family: .systemLarge) }
            }
        }
        .padding(24)
        .background(dark ? Color(red: 0.05, green: 0.05, blue: 0.07) : Color(red: 0.93, green: 0.93, blue: 0.95))
        .environment(\.colorScheme, dark ? .dark : .light)
    }
}
@MainActor func render() {
    let r = ImageRenderer(content: Sheet()); r.scale = 2
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out)); print("wrote \(out)")
    } else { print("render failed") }
}
MainActor.assumeIsolated { render() }
