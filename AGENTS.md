# diamond-sutra-bar  (app name: "Daily Sutra", bundle: DailySutra.app)

A macOS menu bar app ("Daily Sutra") that shows a daily contemplative verse
drawn randomly from the combined pool of the **Diamond Sutra**
(金剛般若波羅蜜經, 32 品) and the **Heart Sutra** (般若波羅蜜多心經). Each verse
shows the classical Chinese line, a modern English verse, a plain-language
explanation, and a reflective meaning — toggleable between EN and 中. The
app does not show which sutra a verse is from.

## Purpose

Daily contemplation aid. One verse rotates in per day, drawn randomly from
the combined Diamond + Heart pool; the user can switch language (中 | EN),
navigate prev/next, resize text, copy, resize the panel, and quit. Click the
menu bar icon to open the panel; it closes on focus loss. The sutra a verse
belongs to is not shown.

## Tech Stack

- Swift 5.9 / SwiftUI + AppKit menu bar app (`NSStatusItem` + a resizable
  borderless-style utility `NSPanel`; replaces NSPopover so the user can drag
  to resize). `hidesOnDeactivate` closes it on focus loss.
- Swift Package Manager (no Xcode project). `Package.swift` declares the
  executable target `DailySutra` and bundles `Resources/verses.json`.
- Build: `./build.sh` → `build/DailySutra.app` (assembles bundle + Info.plist).
- Deployment target: macOS 14 (`platforms: [.macOS(.v14)]`).
- `LSUIElement: true` — no Dock icon, menu bar only.

## Data

`Sources/DailySutra/Resources/verses.json` — 42 entries (32 diamond + 10 heart):

```
{ index, sutra, titleZh, titleEn, zh, en, verseEn, verseZh, explEn, explZh, meaning, meaningZh }
```

- `sutra`: `"diamond"` or `"heart"`.
- `zh` (diamond): Kumārajīva text, public domain (5th c.). Sourced from
  Wikisource (`{{PD-old}}`); cross-reference CBETA T08n0235.
- `en` (diamond): Gemmell 1912 translation (Project Gutenberg #64623,
  pre-1928, PD). Inline footnote markers `[N]` stripped; footnote blocks
  dropped. Not shown in the panel; kept as bundled reference.
- Heart Sutra: canonical 玄奘 (Xuanzang) text, public domain (7th c.,
  CBETA T08n0251). The Heart Sutra is a single continuous text (~260 chars);
  this app segments it into 10 contemplatable lines. `zh` holds the full
  sutra; `verseZh` is the line for that entry. `en`/`verseEn` are the app
  author's modern paraphrase (no PD English translation is bundled for Heart).
- `verseEn` / `explEn` / `meaning` (both sutras): modern English verse
  (app author's paraphrase), plain-language explanation, and reflective
  meaning. Editorial, NOT the canonical PD text.
- `verseZh`: authentic classical Chinese line from the section (PD sutra).
- `explZh` / `meaningZh`: modern Traditional Chinese (zh-tw) explanation and
  reflection, authored for this app.

The panel displays, per the selected language (中 | EN, persisted in
`UserDefaults` key `AppLang`): header `Daily Sutra Verse — <weekday>`, the
verse (pull-quote in EN; classical line in 中), a short explanation, then a
`Reflection` / `省思` block. No sutra name is shown. Prev/Next/Today nav,
A−/A+ font scale (persisted in `FontScale`, 0.85–1.8), copy, and Quit.
Default panel 400×560, min 320×400, user-resizable.

**Daily pick is a deterministic pseudo-random selection seeded by the date**
(xorshift64 over `YYYYMMDD`) across the **entire pool** (Diamond + Heart, 42
entries), so the same verse shows all day and a new random one appears
tomorrow. Prev/Next browse sequentially through the pool; Today resets to
today's pick.

## Regenerating the text

`python3 scripts/build_verses.py Sources/DailySutra/Resources/verses.json`
fetches the Diamond Sutra PD sources (Wikisource Chinese + Gutenberg English)
and re-segments by the 32 品. It **merges** the existing authored fields
(`verseEn`, `verseZh`, `explEn`, `explZh`, `meaning`, `meaningZh`) for diamond
entries (keyed by `(sutra, index)`) and **preserves all Heart Sutra entries**
unchanged — re-extraction will not wipe them. Do NOT hand-edit the sutra text
(`zh`/`en`) — re-extract from verified PD sources.

## Structure

```
diamond-sutra-bar/
├── Package.swift
├── build.sh
├── Info.plist
├── Sources/DailySutra/
│   ├── SutraApp.swift      # @main App, AppDelegate, status item + resizable NSPanel
│   ├── Verse.swift         # Verse, AppLang, VerseStore (loads bundled JSON)
│   └── Resources/verses.json
└── build/DailySutra.app  (build output, gitignore)
```

`scripts/build_verses.py` — fetches the Diamond Sutra PD sources and rebuilds
the diamond `zh`/`en`; preserves authored fields and all Heart Sutra entries
(network required).

## Build & Run

```
swift build              # debug
./build.sh               # release + assemble .app bundle
open build/DailySutra.app
```

## Conventions

- No Xcode project file; SPM only. Do not add `.xcodeproj`.
- No new dependencies. Stdlib + AppKit/SwiftUI only.
- Sutra text is religious and public-domain: never paraphrase or fabricate.
  Re-extract from verified PD sources when updating.
- `verseEn`/`explEn`/`meaning` and the zh-tw counterparts are the app author's
  editorial rendering (paraphrase + reflection), clearly not a doctrinal claim;
  keep them descriptive and contemplative.

## Children

None.