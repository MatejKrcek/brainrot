// Renders the Home Screen sizes of the Brain health widget at several health levels to a PNG (macOS; Lock Screen families are iOS-only).
// usage: scripts/preview_widget.sh out.png   (concatenates the needed sources; see the .sh)
import SwiftUI
import AppKit
import WidgetKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "widget_preview.png"
let dark = CommandLine.arguments.contains("dark")
let store = CommandLine.arguments.contains("store")
func snap(_ m: Int) -> RotSnapshot { RotSnapshot(minutes: m, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: true) }
struct Tile<C: View>: View {
    let w: CGFloat, h: CGFloat
    var rot: Double = 0
    @ViewBuilder var content: C
    var body: some View {
        content.frame(width: w, height: h)
            .background {
                ZStack {
                    (dark || store) ? Color(red: 0.11, green: 0.11, blue: 0.12) : .white
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
/// 6.9" App Store frame (660×1434 @2x = 1320×2868): widgets on a dark Home-Screen-like backdrop.
struct StoreSheet: View {
    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 40)
            VStack(spacing: 6) {
                Text("Your brain, on your Home Screen").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Widgets update as you scroll. Lock Screen too.").font(.system(size: 16)).foregroundStyle(.white.opacity(0.7))
            }
            .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Tile(w: 170, h: 170, rot: snap(8).rot) { HealthWidgetContent(snap: snap(8), family: .systemSmall) }
                Tile(w: 170, h: 170, rot: snap(75).rot) { HealthWidgetContent(snap: snap(75), family: .systemSmall) }
            }
            Tile(w: 356, h: 170, rot: snap(35).rot) { HealthWidgetContent(snap: snap(35), family: .systemMedium) }
            Tile(w: 356, h: 376, rot: snap(95).rot) { HealthWidgetContent(snap: snap(95), family: .systemLarge) }
            Spacer(minLength: 40)
        }
        .frame(width: 660, height: 1434)
        .background(
            LinearGradient(colors: [Color(red: 0.16, green: 0.12, blue: 0.20), Color(red: 0.03, green: 0.03, blue: 0.05)],
                           startPoint: .top, endPoint: .bottom))
        .environment(\.colorScheme, .dark)
    }
}

@MainActor func render() {
    if store {
        let r = ImageRenderer(content: StoreSheet()); r.scale = 2
        if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: URL(fileURLWithPath: out)); print("wrote \(out)")
        } else { print("render failed") }
        return
    }
    let r = ImageRenderer(content: Sheet()); r.scale = 2
    if let img = r.nsImage, let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: out)); print("wrote \(out)")
    } else { print("render failed") }
}
MainActor.assumeIsolated { render() }
