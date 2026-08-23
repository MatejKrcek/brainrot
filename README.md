# Gray Matter

iOS app (SwiftUI, iOS 17+) that shows what short-form scrolling does to your brain. Pick the apps that drain you
(Instagram, TikTok, YouTube…), set a daily limit, and a realistic brain on your Home Screen degrades from
**100% brain health** to 0% as the minutes pile up. Optional blocking pauses the apps once the limit is reached.

```
GrayMatter/              app: onboarding, home (brain + today), settings
Shared/                  code used by every target: store, model, realistic brain drawn in SwiftUI Canvas
SharedScreenTime/        FamilyControls / DeviceActivity helpers (selection, shield, schedules)
GrayMatterWidget/        WidgetKit – brain only; small / medium / large + Lock Screen circular & rectangular
GrayMatterMonitor/       DeviceActivityMonitor ext – turns usage thresholds into a minute counter, applies shield
GrayMatterReport/        DeviceActivityReport ext – exact per-app usage rendered inside the app
GrayMatterShield/        custom shield screen shown over a blocked app
GrayMatterShieldAction/  shield buttons
project.yml              XcodeGen spec → GrayMatter.xcodeproj
scripts/make_icon.sh     renders the app icon from the same brain drawing
scripts/preview_brain.swift  renders BrainView at several health levels to a PNG (macOS) for design iteration
```

## How it works

1. **Onboarding** → Screen Time permission → choose apps/categories (`FamilyActivityPicker`) → daily limit, optional blocking.
2. **Tracking.** The app schedules an all-day `DeviceActivity` with ~150 threshold events (every minute to 90 min, then every 5 min).
   Each threshold wakes `GrayMatterMonitor`, which writes `minutesToday` into the App Group and reloads widgets.
   Apple doesn't let apps read raw usage; the sandboxed `GrayMatterReport` extension shows exact per-app numbers in-app.
3. **Brain health** = 100 % − minutes/limit. Stages: Sharp → Foggy → Fading → Failing → Flatlined. `Shared/BrainView.swift`
   draws a lateral-view brain (gyri tubes on a flow field, cerebellum, stem, inner shadow, sheen) and degrades it:
   pink → olive → necrotic patches, veins, mould, darkening, drips.
4. **Blocking (optional).** Over the limit the selected apps are shielded. "Unblock for 15/30/45 min" lifts the shield;
   a one-shot `DeviceActivity` schedule re-applies it (`intervalDidEnd`), plus a check on app foreground. iOS minimum is 15 min.
5. **Widget** shows only the brain (system background, adapts to light/dark, accentable on tinted Home Screens).

## Build & run

Requirements: Xcode 26, iPhone on iOS 17+, **paid Apple Developer account** for the Screen Time features.

```bash
brew install xcodegen     # once
xcodegen generate         # regenerates GrayMatter.xcodeproj from project.yml
open GrayMatter.xcodeproj
```

Schemes:
* **GrayMatter** – full app (Family Controls + 5 extensions). Needs a paid team; set `DEVELOPMENT_TEAM` in `project.yml`.
  For TestFlight/App Store additionally request the Family Controls *distribution* entitlement from Apple
  (Developer portal → Contact us). Local device installs only need the capability in Xcode.
* **GrayMatterLite** – same code without Family Controls and without the Screen Time extensions. Installs on a free
  Personal Team; runs in demo mode (simulated minutes) with the widget.

Simulator build from the CLI:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project GrayMatter.xcodeproj -scheme GrayMatter \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' CODE_SIGNING_ALLOWED=NO build
```
Launch arguments for testing: `--minutes=80` (sets today's usage, skips onboarding), `--settings`.

## App Store notes

* Bundle IDs: `com.matejkrcek.graymatter[.widget|.monitor|.report|.shield|.shieldaction]`, App Group `group.com.matejkrcek.graymatter`.
* No network access, no analytics, no accounts. Usage data never leaves the device (Apple enforces this for the report extension).
* Privacy nutrition label: "Data not collected".
