# Daily Sutra

![Lotus Icon](AppIcon.svg) 

A contemplative macOS menu bar app delivering one verse from the **Diamond Sutra** each day, paired with modern explanation and reflective meaning.

![macOS](https://img.shields.io/badge/macOS-14+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green)

Each morning, click the menu bar lotus icon to receive a single verse with:
- Modern English paraphrase and classical Chinese line
- Plain-language explanation  
- Reflective meaning (app author's interpretation)
- Personalized daily blessing with weekday

The verse is **deterministically selected by date** — same verse every day, everywhere, forever. No algorithms, no recommendations, only mathematics. Access full classical translations and extensive commentary by tapping "Full Text."

Built with SwiftUI + AppKit, Swift Package Manager. Native macOS, no web dependencies.

## Features

### Core
- 🕉️ **32 Diamond Sutra chapters** — full classical texts, modern translations, scholarly commentary
- 🌐 **Bilingual**: English ↔ 繁體中文, toggle anytime, one-tap language switch
- 📅 **Deterministic daily pick** (xorshift64 algorithm) — same verse every day, everywhere, reproducible forever
- 🎨 **Minimalist lotus icon** — contemplative design, menu bar-optimized
- 🪟 **Floating panel** (400×560, resizable 320×400 min) — non-intrusive, draggable, dismissible

### Navigation & Exploration
- ⬅️ ➡️ **Arrow key navigation** — browse verses by calendar day
- 📅 **Calendar picker** — jump to any past date and read that day's verse
- ❤️ **Favorites** — save verses (heart icon), persistent list
- 📖 **Full Text toggle** — tap "Full Text" to reveal classical translations and extensive commentary
- 🔍 **Search-free design** — intentional simplicity, no filtering or algorithms

### Customization
- 🔤 **Font scaling**: 0.85× to 1.8× (persisted)
- 🔔 **Daily notifications** — opt-in reminder at user-selected time (default 8am)
- 📍 **Pin panel** — keep visible across app switches (toggleable)
- 🚀 **Launch at Login** — auto-start via `SMAppService`
- 🌓 **Light/dark mode** — auto-adapts to system appearance

### Accessibility & Keyboard
| Shortcut | Action |
|----------|--------|
| ← / → | Previous / Next verse |
| T | Return to today |
| Cmd+C | Copy formatted verse |
| Esc | Close panel |
| Language toggle | Header menu (⋮) |

### Copy & Share
- 📋 **Formatted copy** (Cmd+C) — verse + title + explanation + blessing + weekday
- 🖇️ **Works in any app** — paste into email, notes, social media

### Onboarding
- 🎓 **5-step first-run flow** — interactive guide to navigation, favorites, browsing, copying
- ⏩ **Skip anytime** — get to the verse immediately if you prefer
- 💾 **Persistent tracking** — onboarding shows once, never again

Main view: Verse + explanation + blessing. Tap "Full Text" for classical translations.

## Installation

### From Release (Easiest)

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
│       ├── verses.json             # 32 Diamond Sutra chapters
│       ├── AppIcon.icns            # App icon (1024×1024 + all sizes)
│       └── MenubarIcon.png         # Menu bar icon (18×18 + retina @2x)
├── SutraKit/
│   └── SutraKit.swift              # Models: Verse, VerseText, DailyPick
└── PRODUCT.md                      # Product specification
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
- **32 chapters** — fully curated with classical texts, translations, and scholarly annotations

### Original Work

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

**Daily Sutra v1.0.9** | Made with 🙏 for contemplation and practice
