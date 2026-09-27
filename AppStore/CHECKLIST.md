# App Store — what you have to do by hand

Everything in the repo is ready (privacy manifest, export compliance flag, icons, versions, archive script).
These steps need the Apple developer account, not code.

## 1. Family Controls distribution entitlement (blocker — do this first, Apple takes days to weeks)
The development entitlement works for local installs; the App Store build needs the **distribution** one.
- https://developer.apple.com/contact/request/family-controls-distribution
- Request it for the app **and each extension**: `com.matejkrcek.graymatter`, `.monitor`, `.report`, `.shield`, `.shieldaction`.
- Explain: personal screen-time awareness app, individual authorisation only, no parental controls, no data leaves the device.
- Until it is approved, `scripts/archive.sh` fails at signing with a Family Controls provisioning error. TestFlight needs it too.

## 2. Developer portal identifiers (Xcode does most of it with automatic signing)
- App IDs for the 5 bundle IDs above with capabilities: App Groups (`group.com.matejkrcek.graymatter`) on all,
  Family Controls on all five. Open the project in Xcode once with the team selected and let it register them.

## 3. App Store Connect
- New app: name **Brain Health**, bundle ID `com.matejkrcek.graymatter`, SKU `brainhealth`.
- Paste listing text from `AppStore/METADATA.md`; privacy policy URL points at `AppStore/PRIVACY.md` in this repo
  (or host it on matejkrcek.com if you prefer a nicer URL).
- App Privacy: "Data not collected". Age rating questionnaire: all "None" → 4+.
- Upload screenshots (list in METADATA.md).

## 4. Build & upload
```bash
scripts/archive.sh              # archive Release + upload to App Store Connect
scripts/archive.sh --no-upload  # archive only
```
Xcode must be signed in with the team's Apple ID (Xcode → Settings → Accounts). `manageAppVersionAndBuildNumber`
is on, so App Store Connect bumps the build number for you; bump `MARKETING_VERSION` in `project.yml` for new versions.

## 5. Submit
- TestFlight first: install on your iPhone, allow Screen Time, pick apps, add both widgets, wait a day.
- Then "Add for Review" with the review notes from METADATA.md.

## Known review risks
- Reviewers sometimes reject Screen Time apps for a missing explanation of why the entitlement is needed → the onboarding
  screen and review notes cover it.
- If they test on a device without Screen Time, the demo card shows; that is intentional and explained in the notes.
