# App Store Connect — listing

**Name:** Brain Health
**Subtitle (30):** See what scrolling does to you
**Bundle ID:** cz.krcek.greymatter · **SKU:** brainhealth
**Primary category:** Health & Fitness · **Secondary:** Lifestyle
**Price:** Free · **Age rating:** 4+ (no objectionable content; the rotting brain is cartoon-style)
**Privacy policy URL:** https://github.com/MatejKrcek/brainrot/blob/main/AppStore/PRIVACY.md
**Support URL:** https://github.com/MatejKrcek/brainrot/issues
**Copyright:** 2026 Matěj Krček

## Promotional text (170)
A realistic brain on your Home Screen that rots as you scroll. Pick the apps that drain you, set a daily limit, and watch what an hour of TikTok actually costs.

## Description
Brain Health turns your screen time into something you can't ignore: a brain.

Choose the apps that drain you — TikTok, Instagram, X, LinkedIn, Threads or anything else on your iPhone — and set a daily limit. From the first minute, the brain on your Home Screen starts to change: pink and sharp in the morning, foggy by lunch, and if you keep going, dark, mouldy and crawling with flies by the evening.

WIDGETS THAT TELL THE TRUTH
• "Screen time": your brain, today's minutes, how much is left and one thing you could have done instead.
• "Brain": just the brain. No numbers, no excuses.
• Home Screen (small, medium, large) and Lock Screen (circular, rectangular, inline). Light and dark.

INSTEAD, YOU COULD HAVE…
Every time you open the app it tells you what the minutes could have been: a run, a call to your parents, a few chapters of a book, a nap. Different every time.

OPTIONAL BLOCKING
Over the limit? The selected apps get a pause screen. Unblock for 15, 30 or 45 minutes when you really need to — the extra time still counts.

PRIVATE BY DESIGN
Built on Apple's Screen Time framework. Your usage never leaves your iPhone: no account, no server, no analytics, no ads. Ever.

Brain Health is not a medical app. It just makes the cost of scrolling visible.

## Keywords (100)
screen time,brain rot,digital detox,focus,app limit,social media,tiktok,instagram,widget,habit,doomscroll

## What's New (1.0)
First release.

## Screenshots to take (6.9" iPhone 17 Pro Max + 6.5" iPhone 11 Pro Max, portrait)
1. Home with a healthy brain, ~15 min — "100% brain. For now."
2. Home with a rotting brain at 1 h 35 min, quote card visible — "This is your brain on 95 minutes."
3. Home Screen with the medium widget on a dark wallpaper.
4. Tracked apps screen.
5. Lock Screen widgets.
Launch with `--minutes=15` / `--minutes=95` on the simulator for 1–2.

## App Review — notes
Brain Health uses the Family Controls / Screen Time API (individual authorisation only, never parental). On first launch the app asks for Screen Time access; after that, use "Tracked apps" to pick apps in Apple's picker. Minute counts are delivered by a DeviceActivityMonitor extension when usage thresholds are crossed; exact per-app numbers are rendered by the DeviceActivityReport extension.

To see the brain change without waiting: on a device where Screen Time is not authorised the app runs in demo mode with "+5 / +15 / +30 min" buttons under "Demo" on the Home screen. No login is needed. The app makes no network requests.

## Privacy nutrition label (App Store Connect → App Privacy)
Data not collected. (Usage data is processed on device by Apple's framework and never leaves it.)
