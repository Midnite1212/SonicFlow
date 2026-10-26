---
name: SonicFlow
description: A night-session timing panel for local Mac dictation, where every latency is a livery stripe whose length is its time.
colors:
  ground: "#0F1A33"
  board: "#132042"
  panel: "#18264A"
  seam: "#26365F"
  text: "#E8ECF5"
  secondary: "#AEB8D0"
  tertiary: "#8392B5"
  cyan: "#2FD3F0"
  blue: "#3D6BFF"
  violet: "#8B5CF6"
  blue-text: "#7F9CFF"
  violet-text: "#B59BFA"
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
  field: "7px"
  panel: "10px"
  capsule: "9999px"
spacing:
  hint: "4px"
  tight: "8px"
  gap: "12px"
  panel-gap: "14px"
  stack: "16px"
  panel-inset: "18px"
  pane-inset: "24px"
  onboarding-inset: "32px"
components:
  window:
    backgroundColor: "{colors.ground}"
    width: "980px"
    height: "680px"
  sidebar:
    backgroundColor: "{colors.board}"
    textColor: "{colors.text}"
    width: "200px"
  panel:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.panel}"
    padding: "{spacing.panel-inset}"
  panel-title:
    textColor: "{colors.secondary}"
    typography: "{typography.label}"
  today-strip:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.panel}"
    padding: "14px 0"
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
  stripe-budget-tick:
    backgroundColor: "{colors.tertiary}"
    width: "1px"
  setting-hint:
    textColor: "{colors.tertiary}"
    typography: "{typography.callout}"
  quiet-picker:
    textColor: "{colors.secondary}"
    typography: "{typography.body}"
  search-field:
    backgroundColor: "{colors.panel}"
    rounded: "{rounded.field}"
    height: "28px"
    padding: "0 10px"
  pill:
    backgroundColor: "{colors.ground}"
    rounded: "{rounded.capsule}"
    typography: "{typography.pill}"
    width: "230px"
    height: "40px"
    padding: "0 14px"
---

# Design System: SonicFlow

## Overview

**Creative North Star: "The Night-Session Timing Panel"**

SonicFlow is a timing console at a velodrome after dark. Panels sit on an infield navy ground, one step of lightness above it and edged by a hairline seam. The surface is flat colour: no shadows, no glow, no gradients. The logo's cyan, blue and violet appear only as a speed scale. Every latency is drawn as a livery stripe, and its length is its time on one fixed scale, so any two stripes anywhere in the app compare by length.

The window is opened now and then, so its density is calm. It shows speed first, then whether the engine is ready, then what was said, and every other surface is a tidy panel away. The pill is the one surface seen dozens of times a day. It floats over other apps and never takes focus. Everything else stays native Mac: system sidebar, system controls, SF Pro, standard window chrome.

The world rejects the category default of grey or white stat cards with one blue accent, and the generic neon AI look.

**Key Characteristics:**
- Navy ground, panels one lightness step up, a 1px seam for every edge and divider.
- Cyan, blue and violet mean speed and nothing else: under 200 ms, under 500 ms, slower.
- One stripe scale everywhere: 0–600 ms, with a 500 ms budget tick.
- SF Pro throughout, tabular digits for every figure.
- The same dark world in both system appearances.

## Colors

A cool navy ladder carries structure, and three saturated logo hues carry one meaning: how fast it was.

### Primary (the Speed Scale)
- **Speed Cyan** (#2FD3F0): a time under 200 ms. It fills the stripe and is also the text colour for that time. In the pill, cyan colours the live input-level bars while listening.
- **Speed Blue** (#3D6BFF): stripe fill for 200–499 ms.
- **Speed Violet** (#8B5CF6): stripe fill for 500 ms and slower.
- **Blue Text** (#7F9CFF): the text colour for a 200–499 ms figure. Speed Blue is too dark to read as text on navy.
- **Violet Text** (#B59BFA): the text colour for a figure of 500 ms or more, for the same reason.

The thresholds come from `Theme.Speed(ms:)`: `ms < 200` is fast, `ms < 500` is normal, anything else is slow. A stripe takes the fill colour and its figure takes the text colour of the same step.

### Status
- **Ready Green** (#4CC38A): the 8px engine-online dot, the "Engine running" label, granted-permission checks, and the control tint (switches, default buttons).
- **Alert Coral** (#F2706A): the engine-offline dot, "Needs permission", "Engine not reachable", and the pill's recording dot while listening.

### Neutral
- **Infield Navy** (#0F1A33): the ground behind every pane, the window background, the onboarding background and the pill body (at 96% opacity). It also colours the stripe's break notch.
- **Board Navy** (#132042): the sidebar column.
- **Panel Navy** (#18264A): panels, the Today strip, the search field and the onboarding practice editor.
- **Seam** (#26365F): every 1px edge: panel strokes, in-panel dividers, full-width dividers, list separators, the empty stripe track, and inactive onboarding step dots.
- **Off-White** (#E8ECF5): primary text, the command-mode wand, and the pill's level bars in command mode.
- **Slate** (#AEB8D0): panel titles, row labels, explanatory copy, the "ms" unit, picker values and the "Edit" tag.
- **Dim Slate** (#8392B5): metadata (times, app names), setting hints, key labels in key/value rows, placeholders, the budget tick and the pill's processing dot.


### Named Rules
**The One Job Rule.** Cyan, blue and violet encode latency. The one other use is cyan for the pill's live input-level bars while it is listening. A speed colour on anything else is a false reading. Use status colours for state and Off-White for mode.

**The Readable Twin Rule.** Each speed step has a fill and a text colour. Stripes use the fill (cyan, blue, violet), and figures use the text colour (cyan, blue-text, violet-text). Never set a figure in Speed Blue or Speed Violet.

**The Command Is Not Speed Rule.** Command mode is shown by the wand symbol and off-white level bars, never by a speed colour.

Controls take Ready green as their tint (`RootView.tint(Theme.ready)`), so switches and default buttons never borrow a speed colour. Links and secondary actions ("Show All", "Copy", "Add App…") are Secondary text. Onboarding's current step dot is Text and granted permissions are Ready.

## Typography

**Display Font:** SF Pro (system font)
**Body Font:** SF Pro (system font)
**Label/Mono Font:** none. Figures use SF Pro's tabular digits (`.monospacedDigit()`), not SF Mono.

**Character:** One family keeps the window native Mac. Tabular digits line figures up in columns without the width of SF Mono, which reads as code next to prose.

### Hierarchy
Sizes are the macOS text styles the code names, given here in points.
- **Display** (semibold, 64pt, tabular): the latest release-to-text time on Home, coloured by its speed step. A `title2` medium "ms" unit in Slate sits beside it on the first baseline.
- **Headline** (`largeTitle` semibold, 26pt): onboarding welcome and done screens only.
- **Title** (`title` semibold, 22pt): onboarding step titles and Home's "No dictations yet".
- **Figure** (`title2` semibold, 17pt, tabular): Today strip values.
- **Body** (`body`, 13pt): dictated text, setting labels and explanations. Rows truncate to one line; History shows the full text, selectable.
- **Callout** (`callout`, 12pt): metadata rows, key/value rows, setting hints, and every ms figure in a row (tabular).
- **Label** (`subheadline` semibold, 11pt): panel titles in Slate and History day headers.
- **Caption** (`caption`, 10pt, tabular): stripe scale labels ("0", "500 ms budget"). In semibold, the "Edit" tag.
- **Pill** (system 12pt medium, tabular): the pill's elapsed timer and live ms count.

### Named Rules
**The Tabular Figures Rule.** Every number that can change or sit in a column (latencies, times of day, counts, the pill timer) uses tabular digits. Times are written as `Format.ms`: a rounded integer, a space, then "ms".

## Layout

The main window is a native `NavigationSplitView`: a Board Navy sidebar 200–240px wide (ideal 200), and a detail pane on Infield Navy. The window opens at 980×680, its minimum size is 820×560, and the title bar is transparent over full-size content.

- **Home** is a scrolling column, max 1100px, with 24px insets and 16px between rows. The top row holds a flexible Latency panel beside a fixed 290px Engine panel, both stretched to the same height. Below them come the Today strip and then the Recent panel.
- **Settings and Styles** use `panelColumn()`: a centred column, max 760px, with 24px insets and 16px between panels.
- **History, Dictionary and Snippets** are full-bleed: a controls band (24px horizontal and 16px vertical padding), a full-width seam, then a native List on the ground with seam separators.
- **Onboarding** is a centred column, max 520px, with 32px padding and a seam-topped footer (16px padding). The footer holds step dots (7px) on the left and Back/Continue on the right.
- **Rows** use fixed columns so that figures align. Recent rows: time 66px, app 80px, text flexible, stripe 96px, ms 64px trailing. History rows: stripe 160px. Stripe rows: label 96px, stripe flexible, ms 64px trailing.
- **The pill** is a 230×40 non-activating panel, centred horizontally 24pt above the bottom of the visible frame on the screen that holds the mouse. It joins all Spaces and ignores the mouse.

## Elevation & Depth

The window is flat. Depth comes from a step of lightness (ground, then board, then panel) and a 1px seam, never from a drawn shadow, glow or gradient.

### Shadow Vocabulary
- **Pill window shadow** (`NSPanel.hasShadow = true`, system-drawn): the one shadow in the product. The pill floats over arbitrary app content, and the native window shadow separates it from whatever is underneath.

### Named Rules
**The Seam, Not Shadow Rule.** Separate surfaces with a lightness step and a 1px Seam stroke. Draw no shadows in SwiftUI. The pill's system window shadow is the only exception.

## Shapes

Corners are gentle and few. Panels and the Today strip use a 10px radius, the search field 7px, and the pill and stripes are full capsules. Every container has a 1px Seam stroke on the same shape. Stripes have capsule ends, and a filled stripe is never shorter than its own height, so the smallest time still shows a round cap.

## Components

### Speed Stripe (signature)
A latency drawn as a livery stripe. The same component appears on Home, every Recent and History row, the processing pill, and the onboarding try-it.
- **Scale:** fill length = track width × min(ms / 600, 1). The scale is fixed at 0–600 ms everywhere, and it never rescales to fit the data.
- **Track:** a 1px Seam capsule across the full width.
- **Fill:** a capsule in the step's fill colour. Heights are 12px (Home hero), 6px (pill, onboarding) or 4px (rows, 7-day median and p95). The frame adds 8px of vertical room.
- **Budget tick:** a 1px Dim Slate line at 500/600 of the width, 8px taller than the stripe. It is shown on the Home hero and onboarding, with "0" and "500 ms budget" caption labels under the hero.
- **Over scale:** past 600 ms the fill runs full width and carries a break notch: two 2px Infield Navy bars rotated 20°, 2px apart, 16px from the right end. The notch says the length is not to scale.
- **Empty:** with no time, only the track (and the budget tick, where shown) is drawn, and the figure reads "—" in Dim Slate.
- **Accessibility:** labelled "N milliseconds" or "No time yet".

### Panels / Containers
A console panel: a titled box one step lighter than the ground.
- **Corner Style:** 10px.
- **Background:** Panel Navy, with a 1px Seam stroke.
- **Shadow Strategy:** none (see Elevation & Depth).
- **Internal Padding:** 18px. 14px separates the title row from the content.
- **Title:** the Label style in Slate, with an optional trailing control (for example "Show All" as a link button).
- **Today strip variant:** the same surface without a title. Four equal figures are separated by 1px × 40px vertical seams, with 14px vertical padding and 18px horizontal padding per figure. Each value uses Figure style in Off-White, over a label in Callout Dim Slate.

### Setting Row and Quiet Picker
- **Setting Row:** the label in Off-White Body on the left and its control on the right. An optional hint in Callout Dim Slate sits 4px below and wraps. Rows inside a panel are separated by a Seam.
- **Quiet Picker:** a menu picker shown as its value and a chevron, with no bordered popup and no accent cap. It is borderless, tinted Slate and sized to fit.
- **Toggles:** the native `.switch` style with its label hidden.

### Inputs / Fields
- **Search field:** a plain text field with a Dim Slate magnifying glass, on Panel Navy. It has a 7px radius, a 1px Seam stroke, is 28px high, has 10px horizontal padding and is 140–220px wide.
- **Practice editor (onboarding):** a TextEditor on Panel Navy with an 8px radius and a 1px Seam stroke. It is 100px high with 8px padding, and its placeholder is in Dim Slate.
- **Dictionary and Snippets rows:** native rounded-border text fields. The first column is 200px wide, and a borderless minus-circle delete icon in Dim Slate closes the row.

### Buttons
- **Shape and style:** native macOS buttons (bordered, borderless, link). They get no custom styling.
- **Default action:** marked with `.keyboardShortcut(.defaultAction)` (Continue, Get Started, Open SonicFlow).
- **Text actions in rows:** borderless.
- **Disabled:** the native disabled state (for example "Show All" with no entries, or "Clear All…" with an empty history).

### Lists and Rows
- **Recent row:** a single line with 9px vertical padding: time, app, one-line text preview, an optional "Edit" tag, a 4px stripe and the ms figure in its speed text colour. Rows are separated by a Seam.
- **History row:** the full selectable text, then a metadata line in Callout Dim Slate: time, app, word count, an optional Edit tag, a 4px stripe 160px wide, the ms figure and Copy. A context menu offers Copy and Delete. Rows are grouped under day headers in Label Slate.
- **Empty states:** a native `ContentUnavailableView` in Slate, worded for a stranger ("No dictations yet", "No matches", "No words yet").

### Navigation
- **Sidebar:** a native source list on Board Navy, using SF Symbols labels (house, clock.arrow.circlepath, character.book.closed, text.insert, textformat, gearshape). Count badges show the number of History, Dictionary and Snippets entries.
- **Selection:** the system accent colour (see Do's and Don'ts for why).

### Engine Status
- An 8px dot (Ready Green online, Alert Coral offline) beside "Ready" or "Offline" in semibold. Below it are Callout key/value rows: the key in Dim Slate, the value in Off-White, truncated to one line. If permissions are missing, an Alert Coral "Needs permission" line is followed by one native button for each missing permission.

### Pill (floating)
- **Body:** a 230×40 capsule of Infield Navy at 96% opacity with a 1px Seam stroke and 14px horizontal padding. Its colour scheme is forced dark.
- **Listening:** an 8px Alert Coral dot, 28 level bars (3px wide, 2px apart, 3–22px tall, cyan, animated linearly over 0.1s), and an elapsed `m:ss` timer in Slate.
- **Processing:** the dot turns Dim Slate. A 6px Speed Stripe grows in real time from the moment of release, next to a live integer ms count in its speed text colour.
- **Command mode:** an 11pt semibold `wand.and.stars` symbol in Off-White replaces the dot, and the level bars turn Off-White.

## Do's and Don'ts

### Do:
- **Do** draw every latency as a Speed Stripe on the fixed 0–600 ms scale with the 500 ms budget, so a stripe on Home and a stripe in History compare by length.
- **Do** colour a time by `Theme.Speed(ms:)`: under 200 ms cyan (#2FD3F0), under 500 ms blue (#3D6BFF fill, #7F9CFF text), otherwise violet (#8B5CF6 fill, #B59BFA text).
- **Do** separate surfaces with a lightness step and a 1px Seam (#26365F) stroke.
- **Do** set every changing or columnar number in SF Pro tabular digits.
- **Do** keep the window in the dark world in either system appearance: `window.appearance = .darkAqua` with an Infield Navy (#0F1A33) window background. The pill forces `.dark` as well. This is a recorded exception to following the system appearance.
- **Do** leave sidebar selection on the system accent colour. SwiftUI's tint does not reach the native sidebar, an AccentColor asset needs actool (full Xcode only, and this project builds with the Command Line Tools), and a hand-built sidebar would break the native-Mac commitment. This is a recorded exception.
- **Do** use native macOS controls, SF Symbols and `ContentUnavailableView` before building custom chrome.

### Don't:
- **Don't** use cyan, blue or violet for anything other than a time or the pill's listening level: not progress, success, selection, links or mode.
- **Don't** set a figure in Speed Blue (#3D6BFF) or Speed Violet (#8B5CF6). Use their text twins.
- **Don't** rescale a stripe to fit its data, or draw an over-600 ms stripe without the break notch.
- **Don't** draw shadows, glows or gradients in SwiftUI. The only shadow is the system window shadow under the pill.
- **Don't** use grey or white stat cards with a single blue accent, or neon glow treatments.
- **Don't** use SF Mono for figures.
