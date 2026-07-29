# Daily Sutra

A macOS menu bar app that shows a daily contemplative verse drawn randomly from
the **Diamond Sutra** (金剛般若波羅蜜經) and the **Heart Sutra** (般若波羅蜜多心經).

Each day the app picks one verse (deterministic per date, so the same verse
shows all day and a new one appears tomorrow) and shows the classical Chinese
line, a modern English verse, a plain-language explanation, and a short
reflection. The app does not show which sutra a verse is from.

Built with SwiftUI + AppKit. No Xcode project — Swift Package Manager only.

## Features

- Menu bar icon (no Dock icon; `LSUIElement`) opens a resizable panel.
- Daily random pick across the combined Diamond (32 品) + Heart (10 lines) pool.
- 中 / EN language toggle (persisted).
- A− / A+ font scale (persisted, 0.85–1.8).
- Prev / Next / Today navigation, copy-to-clipboard, Quit.
- Panel default 400×560, min 320×400, user-resizable; closes on focus loss.

## Build & Run

```
swift build              # debug
./build.sh               # release + assemble .app bundle
open build/DailySutra.app
```

Requires macOS 14+ and the Swift 5.9 toolchain.

## Regenerating the sutra text

`scripts/build_verses.py` re-fetches the Diamond Sutra public-domain sources
(Wikisource Chinese, Gutenberg English) and re-segments by the 32 品. It merges
the authored editorial fields and preserves the Heart Sutra entries, so
re-running it won't wipe them.

```
python3 scripts/build_verses.py Sources/DailySutra/Resources/verses.json
```

## Content & licensing

- **Diamond Sutra, Chinese** — Kumārajīva (鳩摩羅什) translation, public domain
  (5th c.). Sourced from Wikisource (`{{PD-old}}`); cross-reference
  CBETA T08n0235.
- **Diamond Sutra, English** — Gemmell 1912 translation (Project Gutenberg
  #64623, pre-1928, public domain). Bundled as reference text; footnote markers
  stripped.
- **Heart Sutra** — canonical 玄奘 (Xuanzang) text, public domain (7th c.,
  CBETA T08n0251).
- **verseEn / explEn / meaning** (both sutras) and the **zh-tw** counterparts
  (verseZh lines excepted, which are the authentic classical text) are the app
  author's modern editorial rendering — paraphrase and contemplative
  reflection, not the canonical sutra text and not a doctrinal claim.

The source code in this repository is the author's own work; see the commit
history. If you reuse the bundled public-domain sutra text, respect the
provenance noted above.