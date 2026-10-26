---
version: 1
slug: "client-macos-sources-sonicflow-mainwindow-swift"
primary_target: "client/macos/Sources/SonicFlow/MainWindow.swift"
related_targets: ["client/macos/Sources/SonicFlow/Pill.swift","client/macos/Sources/SonicFlow/OnboardingView.swift"]
---

# SonicFlow app window, pill, onboarding, menu

Scope: the macOS app's main window (Home, History, Dictionary, Snippets, Styles, Settings), the floating pill, first-run onboarding, and the menu-bar menu. Mode: Operate.

Job: the window is opened occasionally to see how fast dictation is, review what was said, and tune words, snippets, styles and models. The pill is seen dozens of times a day mid-task in other apps. Home leads with speed. Must not read as the generic neon AI look, un-Mac-like, or busy.

## Direction contract

THESIS: A night-session timing panel. Persistent console panels on the velodrome's navy, every latency drawn as a livery stripe whose length is its time. Refuses the category default: grey or white stat cards with one blue accent.

OWN-WORLD: Infield navy ground, board-navy sidebar and panels a step lighter, hairline seams, no shadows, no glow, no gradients. The logo's cyan, blue and violet are a speed scale with one job: under 200 ms cyan, under 500 ms blue, slower violet. Off-white text, slate secondary, SF Pro throughout, figures in its tabular digits (they align in columns without the width of SF Mono, which reads as code next to prose). Command mode is shown by the wand and off-white bars, never a speed colour. Sidebar selection keeps the system accent: SwiftUI's tint does not reach the native sidebar, an AccentColor asset needs actool (full Xcode only; this project builds with the Command Line Tools), and a hand-built sidebar would break the native-Mac commitment.

STORY: Opening the window, you see at once that SonicFlow is fast (the latest time and its stripe), then whether it is ready, then what you said. Everything else is a tidy panel away.

FIRST VIEWPORT: Sidebar with section counts. Top row: a wide Latency panel (latest time large in its speed colour, its stripe on a fixed 0–600 ms scale with a 500 ms budget tick, 7-day median and p95 as thinner stripes) beside an Engine panel (status, models, hotkey, permissions). Then a Today strip (words, speed, saved, streak). Then a wide Recent panel: time, app, text, stripe.

FORM: user-pinned fusion of three cards from round three: Night Velodrome's palette, Speed Stripe's signature, Developer Console's panel layout. seed:2772af55706b19c0

SIGNATURE MOVE: the speed stripe, on one fixed scale everywhere: Home, every History row, the pill while processing, and the onboarding try-it.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
