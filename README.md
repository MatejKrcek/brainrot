# Brainrot 🧠🫠

iOS app (SwiftUI, iOS 17+) that tracks how long you spend in Instagram / TikTok / YouTube (Reels, Shorts…)
and rots a brain on your home screen as the minutes pile up. Locked apps cost a challenge.

```
Brainrot/               the app (onboarding, dashboard, challenges, stats, Dr. Brain, settings)
Shared/                 code shared by every target (store, rot model, brain Canvas drawing, theme)
SharedScreenTime/       FamilyControls/DeviceActivity helpers (selection, shield, schedules)
BrainrotWidget/         WidgetKit: small / medium / large + lock-screen circular / rectangular / inline
BrainrotMonitor/        DeviceActivityMonitor ext – turns usage thresholds into a minute counter, applies shield
BrainrotReport/         DeviceActivityReport ext – exact per-app usage list rendered inside the app
BrainrotShieldConfig/   custom shield screen ("Brain 67% rotten – open Brainrot and earn 15 min")
BrainrotShieldAction/   shield buttons
project.yml             XcodeGen spec → Brainrot.xcodeproj
scripts/render_icon.swift  regenerates the app icon
```

## How it works

1. **Onboarding** → Screen Time permission → pick apps/categories (`FamilyActivityPicker`) → choose mode + daily limit.
2. **Tracking.** The app schedules an all-day `DeviceActivity` with ~150 threshold events (every minute to 90 min, then every 5).
   Each threshold wakes `BrainrotMonitor`, which writes `minutesToday` into the App Group and reloads widgets.
   (Apple doesn't let apps read raw usage — this is the standard trick; the `BrainrotReport` extension shows exact per-app numbers in-app.)
3. **Rot.** `rot% = minutes / limit`. Stages: Fresh → Mushy → Rotting → Decayed → Liquefied (100%+). The brain is drawn in
   SwiftUI `Canvas` and shifts from pink to slime green, grows spots, cracks, drips and flies.
4. **Locking.** Two modes:
   * **Gatekeeper** – selected apps are always shielded; every open requires a challenge → 15/30/45-min window.
   * **Daily limit** – free until the limit, shielded afterwards; challenges buy extra windows.
   Unlock windows are enforced by a one-shot `DeviceActivity` schedule (`intervalDidEnd` → re-shield) plus a
   check on app foreground. iOS minimum window is 15 min.
5. **Challenges.** Breathe (3× 4-7-8), Mental math (5 in a row), Type the vow (no paste), Hold still (30 s), Walk it off (60 steps via CoreMotion). "Surprise me" picks randomly.
6. **Dr. Brain.** Daily verdict. With an Anthropic API key (Settings → stored in Keychain) it calls `claude-opus-5`
   with your last 7 days of minutes (no app names leave the phone); without a key you get the built-in roasts (CZ/EN).
7. **Widgets** read the App Group snapshot; the large one has an "Earn 15 min" button that deep-links to the challenge.

## Build & install on your iPhone

Requirements: Xcode 26, an iPhone on iOS 17+, **a paid Apple Developer account** (see below).

```bash
brew install xcodegen          # once
xcodegen generate              # regenerates Brainrot.xcodeproj from project.yml
open Brainrot.xcodeproj
```

In Xcode: select the `Brainrot` scheme + your iPhone → Run. First launch: allow Screen Time, pick apps, done.
Add widgets: long-press home screen → + → Brainrot.

### ⚠️ Family Controls needs a paid developer team

The Screen Time API (`com.apple.developer.family-controls`) cannot be provisioned on a free *Personal Team*.
`project.yml` currently sets `DEVELOPMENT_TEAM: HRZTF76M9G` (the personal team found on this Mac).
When you have a paid team:

1. Change `DEVELOPMENT_TEAM` in `project.yml` (and optionally `bundleIdPrefix`), run `xcodegen generate`.
2. In Xcode, Signing & Capabilities for **Brainrot, BrainrotMonitor, BrainrotReport, BrainrotShieldConfig, BrainrotShieldAction**
   should show *Family Controls* + *App Groups* (`group.com.matejkrcek.brainrot`); the widget needs only App Groups.
   Xcode registers the capability with Apple automatically for development builds.
3. For TestFlight/App Store you must additionally request the Family Controls distribution entitlement from Apple
   (Developer portal → Contact us → "Family Controls"); local device installs don't need it.

Without the entitlement the app still runs in **demo mode**: no real tracking or locking, but the whole UI,
challenges, stats, Dr. Brain and widgets work (Dashboard has +5/+15/+30 min buttons to simulate scrolling).

### Simulator / CLI

```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project Brainrot.xcodeproj -scheme Brainrot \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' CODE_SIGNING_ALLOWED=NO build
```
Launch arguments for screenshots/testing: `--minutes=80`, `--tab=stats|coach|settings`, `--challenge=math|breathe|type|hold|walk`, `--seed`.

## Known limits (Apple, not us)

* The shield can't open Brainrot directly; "Open Brainrot" closes the blocked app and Brainrot jumps to the challenge on next launch.
* Minute counting is threshold-based (±1 min); exact per-app numbers live only in the in-app report.
* DeviceActivity thresholds reset at midnight with the schedule; if the monitor extension is killed the app re-syncs on launch.
