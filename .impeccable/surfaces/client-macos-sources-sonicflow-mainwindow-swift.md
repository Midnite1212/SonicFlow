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

THESIS: A night-session timing board. Figures and livery stripes set straight on a deep, quiet navy, every latency a stripe whose length is its time, inside the Mac's own Liquid Glass chrome. Refuses the category default: grey or white stat cards with one blue accent, outlined boxes, and neon on saturated navy.

OWN-WORLD: Midnight ground, content unboxed and split by one-device-pixel seams; native glass sidebar and toolbar; grouped forms, tables and toolbar search. The logo's hues in Apple's calibrated system cyan, blue and purple are a speed scale with one job: under 200 ms cyan, under 500 ms blue, slower purple. SF Pro with tabular digits. Glass is chrome; the pill is the one glass surface SonicFlow draws.

STORY: Opening the window, you see at once that SonicFlow is fast (the latest time and its stripe), then whether it is ready, then what you said. Everything else is a tidy panel away.

FIRST VIEWPORT: Glass sidebar in three sections. Top row: the 7-day median as the display figure with its stripe on the fixed 0–600 ms scale and 500 ms budget tick, Latest and Slowest 5% as thinner stripes, beside an Engine column across a vertical seam. A ruled Today band, then Recent rows.

FORM: user-pinned fusion of three cards from round three: Night Velodrome's palette, Speed Stripe's signature, Developer Console's panel layout. seed:2772af55706b19c0

SIGNATURE MOVE: the speed stripe, on one fixed scale everywhere: Home, every History row, the pill while processing, and the onboarding try-it.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
