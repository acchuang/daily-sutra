# Daily Sutra

A contemplative macOS menu bar app delivering one verse from the **Diamond Sutra** and **Heart Sutra** each day, paired with modern explanation and reflective meaning.

![macOS](https://img.shields.io/badge/macOS-14+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green) [![Website](https://img.shields.io/badge/website-daily--sutra.pages.dev-c96442)](https://daily-sutra.pages.dev)

🌐 **Official Site & Interactive Web Simulator**: [https://daily-sutra.pages.dev](https://daily-sutra.pages.dev)

Each morning, click the menu bar lotus icon to receive a single verse with:
- Modern English paraphrase and authentic classical Chinese line
- Plain-language explanation and reflective commentary
- Personalized daily blessing with weekday
- Contemplative emoji matched to the verse theme

The verse is **deterministically selected by date** across the unified pool of Diamond Sutra chapters and Heart Sutra contemplations — the same verse for the same calendar date, anywhere in the world. No algorithms, no recommendations, only mathematics. Access full classical translations and extensive commentary by tapping "Full Text."

Built with SwiftUI + AppKit, Swift Package Manager. Native macOS, zero web dependencies.

## Features

### Core & Contemplation
- 🕉️ **42 Sutra Verses** — curated from the Diamond Sutra (32 chapters) and Heart Sutra (10 contemplations) in a single unified pool
- 📜 **Distilled Reading Card** — serene reading view focused exclusively on scripture, reflection, and blessing
- 🌐 **Bilingual**: English ↔ 繁體中文, instant 1-tap language switch in the header
- 🎨 **Reading Ambience (Warm Paper Tint)** — optional soft parchment / Xuan paper (宣紙) background tint for quiet morning contemplation
- 📅 **Deterministic daily pick** — the same verse for the same calendar date, anywhere, for a given app version; every verse appears exactly once per 42-day cycle
- 🪟 **Floating & dockable panel** (400×560, resizable 320×400 min) — choose between anchored under the menu bar or freely draggable anywhere on screen, dismissible on focus loss

### Navigation & Exploration
- ⬅️ ➡️ **Arrow key navigation** — browse verses day by day
- 📅 **Calendar picker** — jump to any past date and read that day's verse
- ❤️ **Favorites** — save verses (heart icon), persistent list
- 📖 **Full Text toggle** — tap "Full Text" to reveal classical translations and parallel texts
- 🔍 **Search-free design** — intentional simplicity, no filtering or algorithms

### Customization & Settings
- ⚙️ **Dedicated Settings Panel** — clean preferences sheet for system and reading controls
- 📖 **Daily Sutra choice** — draw the daily verse from both sutras (default), Diamond only (32 verses) or Heart only (10 verses); switching can change today's verse
- 📌 **Window Placement (Attached vs Draggable)** — switch between anchored directly beneath the menu bar status icon (centered with 2pt gap and screen edge margins) or freely draggable across screens with coordinate memory; includes smooth 0.2s ease-out snapping animation, resize anchoring (top edge pinned below menu bar), and an instant "Snap to Menu Bar" reset button
- 📜 **Warm Paper Tint** — toggleable soothing cream / charcoal amber undertone
- 🔤 **Font scaling**: 0.85× to 1.8× (persisted with percentage readout)
- 🔔 **Daily notifications** — opt-in reminder at user-selected time (race-free scheduling)
- 📍 **Pin panel** — keep visible across app switches (toggleable)
- 🚀 **Launch at Login** — auto-start via `SMAppService`
- 🌓 **Light/dark mode** — auto-adapts to system appearance

### Accessibility & Controls
| Shortcut / Control | Action |
|--------------------|--------|
| ← / → | Previous / Next verse |
| T | Return to today |
| Cmd+C | Copy formatted verse (with checkmark confirmation) |
| Cmd+, | Open Settings & Preferences sheet |
| Esc | Close panel |
| 1-tap Pill | Switch between English (EN) and Traditional Chinese (中) |
| Header Dock Icon | Toggle between attached to menu bar and freely draggable mode |
| Right-click Icon | Menu bar context menu (Show Verse, Copy Verse, Attach / Snap to Menu Bar, Quit) |
| VoiceOver | Fully discrete button navigation with localized labels |

### Copy & Share
- 📋 **Formatted copy** (Cmd+C) — verse + title + explanation + blessing + weekday
- ✅ **Instant visual feedback** — button confirms with an animated checkmark upon copy
- 🖇️ **Universal paste** — paste into notes, journaling apps, email, or messages

### Onboarding & Guidance
- 🌸 **Gentle inline onboarding** — non-blocking first-run greeting with 1-tap dismissal
- ⌨️ **Keyboard shortcuts cheatsheet** — accessible anytime from Settings

## Installation

### Homebrew

```bash
brew install --cask acchuang/tap/daily-sutra
```

The cask removes the quarantine flag for you, so there is no Gatekeeper step.

### From Release

1. Download latest `DailySutra.zip` from [Releases](https://github.com/acchuang/daily-sutra/releases)
2. Unzip → you get `DailySutra.app`
3. Drag to `/Applications`
4. **First launch** — app is unsigned, so Gatekeeper may block it:
   - Right-click `DailySutra.app` → **Open** → confirm in dialog; or
   - `xattr -dr com.apple.quarantine /Applications/DailySutra.app` from Terminal
5. Lotus icon appears in menu bar. Click to open verse panel.
6. Optional: Enable **Launch at Login** in settings ⋮ menu

**Requires:** macOS 14 (Sonoma) or later

### From Source

```bash
git clone https://github.com/acchuang/daily-sutra.git
cd daily-sutra
./build.sh
open build/DailySutra.app
```

Same Gatekeeper step applies. Code is pure Swift, no Xcode required.

## Development

### Build

```bash
swift build -c release              # Build release binary
./build.sh                          # Assemble .app bundle
open build/DailySutra.app           # Launch
```

### Project Structure

```
Sources/
├── DailySutra/
│   ├── SutraApp.swift              # AppDelegate, VerseViewModel, SutraView, UI
│   ├── DailyNotifier.swift         # Notifications via UserNotificationCenter
│   └── Resources/
│       ├── verses.json             # 42 verses (32 Diamond + 10 Heart)
│       ├── AppIcon.icns            # App icon (1024×1024 + all sizes)
│       └── MenubarIcon.png         # Menu bar icon (18×18 + retina @2x)
└── SutraKit/
    └── SutraKit.swift              # Models: Verse, VerseText, DailyPick
```

### Making Changes

- **UI**: Edit `SutraView` in `SutraApp.swift`
- **Display text**: Edit `VerseText` in `SutraKit.swift` (unified source of truth)
- **Verse content**: Edit `verses.json` (maintain bilingual parity)
- **Icons**: Edit SVG sources, regenerate ICNS/PNG via ImageMagick + iconutil
- **Notifications**: Edit `DailyNotifier.swift`
- **State management**: Edit `VerseViewModel` in `SutraApp.swift`

## Content & Licensing

### Source Material

- **Diamond Sutra, Chinese** — Kumārajīva (鳩摩羅什) translation, public domain (5th c.)
- **Diamond Sutra, English** — Gemmell 1912 translation (Project Gutenberg #64623, public domain)
- **Heart Sutra, Chinese** — Xuanzang (玄奘) translation, public domain (7th c.)
- **Heart Sutra, English** — Max Müller 1894 (Sacred Books of the East, vol. 49, public domain), spelling modernised. Müller translated the Sanskrit, so it differs from Xuanzang's Chinese in places
- **42 verses** — classical texts and translations as credited above, plus the original work below

### Original Work

The paraphrases, explanations, reflections and blessings below were drafted with AI assistance, then reviewed and edited by the author; much of the code was too.

- **verseEn / explEn / meaning** — app author's modern paraphrase and reflective interpretation
- **verseZh / explZh / meaningZh** — bilingual equivalents with traditional Chinese parity
- **Blessings** — personalized daily closings, original to this app
- **Source code** — MIT License, fully open-source

The bundled sutra texts are public domain; respect their provenance if you reuse them.

## Learn More

- [**About Daily Sutra**](ABOUT.md) — Philosophy, design choices, accessibility
- [**PRODUCT.md**](PRODUCT.md) — Product specification and feature list
- [**Releases**](https://github.com/acchuang/daily-sutra/releases) — Download latest version

## Community

Issues and PRs welcome. Please maintain:
- **Bilingual parity** — any change to English must have corresponding Chinese
- **Contemplative tone** — no marketing speak, no jargon
- **Accessibility** — keyboard nav, screen reader labels, WCAG AA color contrast

For major changes, open an issue first.

---

**Daily Sutra v1.2.0** | Made with 🙏 for contemplation and practice
