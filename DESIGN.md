---
name: SonicFlow
description: A night-session timing board for local Mac dictation, where every latency is a livery stripe whose length is its time.
colors:
  ground: "#0D111C"
  panel: "#161D2D"
  seam: "#262E42"
  text: "#E8EBF2"
  secondary: "#A4ACBF"
  tertiary: "#8089A0"
  cyan: "#64D2FF"
  blue: "#0A84FF"
  violet: "#BF5AF2"
  blue-text: "#5EADFF"
  violet-text: "#DA8FFF"
  ready: "#4CC38A"
  alert: "#F2706A"
typography:
  display:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "64pt"
    fontWeight: 600
    fontFeature: "tnum"
  headline:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "26pt"
    fontWeight: 600
  title:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "22pt"
    fontWeight: 600
  figure:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "17pt"
    fontWeight: 600
    fontFeature: "tnum"
  section:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "13pt"
    fontWeight: 600
  body:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "13pt"
    fontWeight: 400
  callout:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12pt"
    fontWeight: 400
  label:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "11pt"
    fontWeight: 600
  caption:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "10pt"
    fontWeight: 400
    fontFeature: "tnum"
  pill:
    fontFamily: "SF Pro, -apple-system, system-ui"
    fontSize: "12pt"
    fontWeight: 500
    fontFeature: "tnum"
rounded:
  capsule: "9999px"
spacing:
  hint: "4px"
  tight: "8px"
  gap: "12px"
  board-gap: "32px"
  pane-inset: "32px"
  onboarding-inset: "32px"
components:
  window:
    backgroundColor: "{colors.ground}"
    width: "980px"
    height: "680px"
  sidebar:
    material: "system Liquid Glass sidebar"
    width: "210px"
  seam:
    backgroundColor: "{colors.seam}"
    height: "1 device pixel"
  latency-readout:
    typography: "{typography.display}"
  stripe-track:
    backgroundColor: "{colors.seam}"
    height: "1px"
  stripe-fast:
    backgroundColor: "{colors.cyan}"
    rounded: "{rounded.capsule}"
  stripe-normal:
    backgroundColor: "{colors.blue}"
    rounded: "{rounded.capsule}"
  stripe-slow:
    backgroundColor: "{colors.violet}"
    rounded: "{rounded.capsule}"
  stripe-instant-tick:
    backgroundColor: "{colors.tertiary}"
    width: "1px"
  pill:
    material: "Liquid Glass, tinted {colors.ground} at 55%"
    rounded: "{rounded.capsule}"
    typography: "{typography.pill}"
    width: "230px"
    height: "40px"
    padding: "0 14px"
---

# Design System: SonicFlow

## Overview

**Creative North Star: "The Night-Session Timing Board"**

SonicFlow is the timing board at a velodrome after dark. The content is set straight on a deep, quiet navy: figures, stripes and hairline rules, with no boxes around them. Every latency is drawn as a livery stripe, and its length is its time on one fixed scale, so any two stripes anywhere in the app compare by length. Cyan, blue and purple, the logo's hues in Apple's calibrated system versions, appear only as that speed scale.

Everything around the content is the Mac's own: the Liquid Glass sidebar and toolbar, grouped forms, tables, search and glass buttons. Glass is chrome, never content. A faint ambient light of the speed hues lies behind the whole window, because glass only shows by bending what is behind it; on flat navy it reads as a plain panel. The one glass surface SonicFlow draws itself is the pill, because it floats over other apps.

The window is opened now and then, so it is calm. It shows speed first, then whether the engine is ready, then what was said.

The world rejects the category defaults: grey or white stat cards with one blue accent, outlined boxes around every group, and neon on saturated navy, which reads as a gaming or AI app rather than a Mac app.

**Key Characteristics:**
- Deep navy ground; content unboxed, separated by one-device-pixel seams.
- Cyan, blue and purple mean speed and nothing else: under 200 ms, under 500 ms, slower.
- One stripe scale everywhere: 0–600 ms, with a tick at 100 ms, where a response starts to feel instant.
- Native chrome: Liquid Glass sidebar and toolbar, grouped forms, tables, `.searchable`.
- SF Pro throughout, tabular digits for every figure.
- The same dark world in both system appearances.

## Colors

A quiet navy ladder carries structure, and three calibrated hues carry one meaning: how fast it was.

### Primary (the Speed Scale)
- **Speed Cyan** (#64D2FF, the system cyan): a time under 200 ms. It fills the stripe and is also the text colour for that time. In the pill, cyan colours the live input-level bars while listening.
- **Speed Blue** (#0A84FF, the system blue): stripe fill for 200–499 ms.
- **Speed Purple** (#BF5AF2, the system purple): stripe fill for 500 ms and slower.
- **Blue Text** (#5EADFF): the text colour for a 200–499 ms figure.
- **Purple Text** (#DA8FFF): the text colour for a figure of 500 ms or more.

The thresholds come from `Theme.Speed(ms:)`: `ms < 200` is fast, `ms < 500` is normal, anything else is slow. A stripe takes the fill colour and its figure takes the text colour of the same step.

### Status
- **Ready Green** (#4CC38A): the engine-online dot, granted permissions, and the control tint (switches, default buttons).
- **Alert Coral** (#F2706A): the engine-offline dot, "Needs permission", errors, and the pill's recording dot while listening.

### Neutral
- **Midnight** (#0D111C): the base of the window behind every pane and onboarding, and the pill's glass tint. It also colours the stripe's break notch.
- **Ambient light** (`AmbientLight`): three heavily blurred discs over Midnight — cyan at 22% top-left behind the sidebar, blue at 16% along the top, purple at 12% bottom-right. It is the one gradient in the product and exists only so the glass has light to bend.
- **Panel** (#161D2D): the onboarding practice editor.
- **Seam** (#262E42): every rule: the Home board's dividers, list separators and the empty stripe track.
- **Off-White** (#E8EBF2): primary text, the command-mode wand, and the pill's level bars in command mode.
- **Slate** (#A4ACBF): secondary text: captions, labels, explanatory copy, the "ms" unit, the "Edit" tag.
- **Dim Slate** (#8089A0): metadata (times, app names), key labels, footers, the instant tick and the pill's processing dot. It holds 4.8:1 on Panel and 5.4:1 on Midnight.

### Named Rules
**The One Job Rule.** Cyan, blue and purple encode latency. The one other use is cyan for the pill's live input-level bars. A speed colour on anything else is a false reading.

**The Readable Twin Rule.** Stripes use the fill colour, figures use the text colour. Never set a figure in Speed Blue or Speed Purple.

**The Command Is Not Speed Rule.** Command mode is shown by the wand symbol and off-white level bars, never by a speed colour.

Controls take Ready green as their tint (`RootView.tint(Theme.ready)`), so switches and default buttons never borrow a speed colour.

## Typography

**Font:** SF Pro (system font) for everything. Figures use its tabular digits (`.monospacedDigit()`), not SF Mono, which reads as code next to prose.

### Hierarchy
- **Display** (semibold, 64pt, tabular): Home's 7-day median release-to-text time, coloured by its speed step, with a `title2` medium "ms" in Slate on the first baseline and a Slate caption beneath saying what it measures. With no median, it shows the latest time and says so. A Callout Dim Slate line under it says how long typing a typical dictation takes at the user's measured speed (or an average 40 wpm, with a "Measure Yours" link).
- **Headline** (`largeTitle` semibold, 26pt): onboarding welcome and done screens.
- **Title** (`title` semibold, 22pt): onboarding step titles and Home's "No dictations yet".
- **Figure** (`title2` semibold, 17pt, tabular): Today values.
- **Section** (`headline`, 13pt): Home's "Engine ready" and "Recent". Forms use the system's own section headers.
- **Body** (`body`, 13pt): dictated text, row labels, explanations.
- **Callout** (`callout`, 12pt): metadata, key/value rows, footers and every ms figure in a row (tabular).
- **Label** (`subheadline` semibold, 11pt): History day headers.
- **Caption** (`caption`, 10pt, tabular): stripe scale labels ("0", "100 ms, feels instant").
- **Pill** (system 12pt medium, tabular): the pill's timer and live ms count.

No eyebrow labels above headings: a figure's caption sits under it.

### Named Rules
**The Tabular Figures Rule.** Every number that can change or sit in a column uses tabular digits. Times are written as `Format.ms`: a rounded integer, a space, then "ms", never grouped ("1413 ms", not "1,413").

## Layout

The main window is a native `NavigationSplitView` with a unified toolbar (`sceneBridgingOptions = [.title, .toolbars]`, `toolbarStyle = .unified`) over full-size content with a transparent titlebar. It opens at 980×680 with a minimum of 820×560.

- **Sidebar:** the system Liquid Glass sidebar, 200–240pt (ideal 210), in three sections: Home and History; Personalize (Dictionary, Snippets, Styles); Setup (Models, Settings). ⌘1–⌘7 select them from the View menu.
- **Home** is a scrolling timing board, max 1100pt wide, with 32pt horizontal and 28pt vertical insets. The top row holds the latency readout beside the engine column (250pt), split by a vertical seam with 32pt either side. A Today band follows, ruled above and below, then Recent.
- **Settings, Styles and Models** are grouped `Form`s (`formStyle(.grouped)`), max 720pt, centred on the ground. Models' Recommended / Browse / My Models switch is a segmented control in the toolbar's principal slot.
- **History** is a native inset `List`, searchable from the toolbar (⌘F), with selectable rows: ⌘C copies, Delete removes. Day headers are plain rows, because sticky section headers draw a grey material bar.
- **Dictionary and Snippets** are editable `Table`s with the add button in the toolbar (⌘N), Delete on the selection with undo, and a one-paragraph footer above a seam.
- **Onboarding** is a centred column, max 520pt, with 32pt padding and a seam-topped footer holding step dots and Back/Continue.
- **Rows** use fixed columns so figures align. Recent rows: time 66pt, app 80pt, text flexible, stripe 96pt, ms 64pt trailing. History rows: stripe 160pt. Stripe rows: label 84pt, stripe flexible, ms 64pt trailing.
- **The pill** is a 230×40 non-activating panel, centred 24pt above the bottom of the visible frame on the screen with the mouse. It joins all Spaces and ignores the mouse.

## Elevation & Depth

Content is flat: no SwiftUI shadows or glows, and no gradient except the ambient light behind the window. Depth belongs to the system: the Liquid Glass sidebar and toolbar float over the content and the ambient light, and grouped forms draw their own rounded section fills.

### Named Rules
**The Glass Is Chrome Rule.** Liquid Glass is for surfaces that float above content: the system sidebar and toolbar, and the pill over other apps. Never put glass behind content in a pane.

**The Seam, Not Box Rule.** Separate groups of content with space and a one-device-pixel Seam (`Seam()`), never with an outlined box.

## Shapes

Stripes and the pill are full capsules. A filled stripe is never shorter than its own height, so the smallest time still shows a round cap. Every other shape (form sections, tables, buttons, the sidebar) is the system's own.

## Components

### Speed Stripe (signature)
A latency drawn as a livery stripe. The same component appears on Home, every Recent and History row, the Models list, the processing pill and the onboarding try-it.
- **Scale:** fill length = track width × min(ms / 600, 1). The scale is fixed at 0–600 ms everywhere and never rescales to fit the data.
- **Track:** a 1px Seam capsule across the full width.
- **Fill:** a capsule in the step's fill colour. Heights are 12px (Home readout), 6px (pill, onboarding) or 4px (rows). The frame adds 8px of vertical room.
- **Instant tick:** a 1px Dim Slate line at 100/600 of the width, 8px taller than the stripe, on the Home readout and onboarding, with "0" and "100 ms, feels instant" caption labels under the readout. Around 100 ms is where a response stops feeling like a wait (Card, Moran and Newell; Nielsen's 0.1 s limit), which means more to someone dictating than an engineering budget does.
- **Over scale:** past 600 ms the fill runs full width and carries a break notch: two 2px Midnight bars rotated 20°, 2px apart, 16px from the right end.
- **Empty:** only the track (and the instant tick, where shown), and the figure reads "—" in Dim Slate.
- **Accessibility:** labelled "N milliseconds" or "No time yet".

### Home board
- **Latency readout:** the Display figure, its caption and the typing comparison, the 12px stripe with the instant tick and scale labels, then Latest and "Slowest 5%" (the 7-day p95) as 4px stripe rows.
- **Engine column:** an 8px status dot beside "Engine ready" or "Engine offline" (Section), then Callout key/value rows (key in Dim Slate, value in Off-White): Hotkey, Mode, Speech, Cleanup, Permissions. Missing permissions show an Alert Coral line and one small button each.
- **Today band:** four equal figures (Figure over a Callout Dim Slate label) split by 1×40pt seams, 18pt vertical padding, seams above and below.
- **Recent:** a Section heading with a small glass "Show All" button, then up to eight rows split by seams.

### Typing test
A sheet from Settings › Typing speed (or Home's "Measure Yours"): a passage on Panel, characters turning Off-White when right and Alert Coral when wrong, a text field, a live wpm figure, and Cancel / Use This Speed. Net wpm counts correctly typed words, five characters to a word. Only the number is saved; time saved and Home's typing line use it.

### Forms
Native grouped forms. A row's explanation is the control label's second `Text`, which the system sets as a secondary line. Buttons inside rows are native bordered buttons; per-model actions are `.controlSize(.small)`. Pickers are the form's native popup.

### Buttons
Glass buttons (`.glass(.regular)` with a clear tint, so the green control tint doesn't colour them) in forms and on Home; bordered before macOS 26. Links and borderless buttons where text is the action. Default actions use `.keyboardShortcut(.defaultAction)`. Toolbar actions use SF Symbols with a help tag naming the shortcut.

### Lists and Tables
- **History row:** the full text, then a Callout Dim Slate metadata line (time, app, word count, optional Edit tag, a 160pt stripe, the ms figure). A copy icon appears on hover; the context menu offers Copy and Delete.
- **Empty states:** native `ContentUnavailableView` in Slate, worded for a stranger, with an add button where one applies.

### Navigation
- **Sidebar:** SF Symbols labels (house, clock.arrow.circlepath, character.book.closed, text.insert, textformat, cpu, gearshape) with count badges for History, Dictionary and Snippets.
- **Selection:** the system accent colour. SwiftUI's tint does not reach the native sidebar, and an AccentColor asset needs actool, which the Command Line Tools lack.

### Pill (floating)
- **Body:** a 230×40 capsule of Liquid Glass tinted Midnight at 55% on macOS 26 (on earlier systems, Midnight at 96% with a Seam border), forced dark, 14px horizontal padding.
- **Listening:** an 8px Alert Coral dot, 28 level bars (3px wide, 2px apart, 3–22px tall, cyan, animated linearly over 0.1 s unless Reduce Motion is on), and an elapsed `m:ss` timer in Slate.
- **Processing:** the dot turns Dim Slate; a 6px Speed Stripe grows in real time from release, next to a live ms count in its speed text colour.
- **Command mode:** an 11pt semibold `wand.and.stars` in Off-White replaces the dot, and the bars turn Off-White.

## Build

SwiftPM records the deployment target (macOS 14) as the SDK version, which makes macOS 26 draw the app in its compatibility look with no Liquid Glass. `build-app.sh` restamps the binary with the real SDK version (`vtool -set-build-version`) before signing.

## Do's and Don'ts

### Do:
- **Do** draw every latency as a Speed Stripe on the fixed 0–600 ms scale with the 100 ms instant tick.
- **Do** colour a time by `Theme.Speed(ms:)`: under 200 ms cyan (#64D2FF), under 500 ms blue (#0A84FF fill, #5EADFF text), otherwise purple (#BF5AF2 fill, #DA8FFF text).
- **Do** set content on the ground and separate it with space and one-device-pixel seams.
- **Do** reach for native structure first: grouped `Form`, `Table`, `List`, `.searchable`, toolbar items, `ContentUnavailableView`.
- **Do** keep the window dark in either system appearance (`window.appearance = .darkAqua`, Midnight background); the pill forces dark too.
- **Do** lead Home with the 7-day median, so one slow dictation can't paint the headline.

### Don't:
- **Don't** use cyan, blue or purple for anything but a time or the pill's listening level.
- **Don't** draw outlined boxes around groups, or stat cards.
- **Don't** put Liquid Glass behind content; it belongs to the chrome and the pill.
- **Don't** use neon or saturated navy; the palette stays quiet so the stripes carry the colour.
- **Don't** set a figure in Speed Blue or Speed Purple, or group digits in a time.
- **Don't** draw shadows, glows or gradients in SwiftUI, beyond the one ambient light behind the window.
- **Don't** use SF Mono for figures, or eyebrow labels above headings.
