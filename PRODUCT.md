# Product

<!-- impeccable:product-schema 1 -->

## Platform

macos

Native macOS (SwiftUI and AppKit, Swift package in `client/macos/`), macOS 14 and later. Not one of the web/ios/android values; native Mac conventions apply.

## Users

Richie first: a developer who dictates all day on an M3 Pro laptop and an M4 Max Mac Studio, into Slack, mail, editors, terminals, and AI coding tools. Other Mac users later: someone who installs it without Richie there must be able to get through setup, understand what each screen does, and trust it, so onboarding and copy are written for a stranger even while the only user is the author.

## Product Purpose

Hold a key, speak, release, and clean text appears in whatever app has focus. SonicFlow replaces OpenWhispr, which was too slow and bloated, and aims for Wispr Flow quality and beyond. Success is dictation that feels instant (release→text around 100–400 ms on the M3 Pro) and text that needs no fixing.

## Positioning

Wispr Flow–quality dictation that runs entirely on your own Mac: faster than the cloud apps, with nothing leaving the machine. Speed comes first; local and private is how it gets fast and the second promise.

## Operating Context

- Lives in the menu bar; a floating pill shows listening and processing while the hotkey is held. The app window (Home, History, Dictionary, Snippets, Styles, Settings) is opened occasionally, not kept open.
- The speech engine runs as a background LaunchAgent; the app talks to it over loopback.
- Used mid-task in other apps: the person's attention is on what they're writing, not on SonicFlow.
- Command mode: select text, hold the hotkey with Shift, speak an edit.

## Capabilities and Constraints

- Hotkey (default Option), hold-to-talk or tap-to-toggle; Esc cancels.
- Local models only: Parakeet (speech) and Qwen3 (cleanup); switchable in Settings.
- Self-correction cleanup ("no wait…"), personal dictionary, snippets, per-app styles (standard, casual, lowercase), command mode.
- Privacy: dictated text and audio are never logged; history is in memory unless the user turns on saving (with a retention period); usage stats hold counts only.
- English only for v0; Mandarin, Cantonese, and Japanese are planned for v1.
- Requires Microphone, Input Monitoring, and Accessibility permissions.

## Brand Commitments

- Name: SonicFlow. "Sonic" means blazing fast; speed should be felt in the product, not just claimed.
- Logo: the neon cyan→blue→violet speed "S" with motion streaks on a dark navy rounded square (`client/macos/Resources/AppIcon.png`). Fixed.
- Native Mac only: SwiftUI/AppKit, no Electron or web views.
- Lean, no bloat: every screen, setting, and line of copy earns its place.

## Evidence on Hand

- Bench results per machine in `bench/results/` and `docs/LATENCY.md` (M3 Pro; M4 Max pending).
- No testimonials, users, or press exist; none may be invented.

## Product Principles

1. Speed is the product: nothing in the UI may add latency to dictation, and the UI should make speed visible.
2. Stay out of the way: the app is felt in other apps (pill, pasted text), not visited; the window is for setup and review.
3. Private by default: anything that stores the user's words is opt-in and says so plainly.
4. Earn every element: fewer, clearer controls over more options.
5. Feel like a Mac app: native conventions over custom chrome.
