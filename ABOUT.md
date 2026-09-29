# About Daily Sutra

## What Is This?

**Daily Sutra** is a macOS menu bar companion app designed for contemplative practice. It delivers one verse from the Diamond Sutra each day, paired with explanation and reflection.

The app exists to support a morning ritual: open, read, close. Not to be a teaching tool, not to replace study, not to gamify practice. Just one verse, every day, forever.

## Design Philosophy

### Deterministic Picks (No Algorithms)

Each verse is selected by date using a simple mathematical function (xorshift64). This means:
- **Same verse every day** — you see it in the morning, your friend sees it in Tokyo, same verse.
- **Reproducible forever** — if the app is gone in 2050, you can regenerate the same sequence.
- **No recommendations** — the app doesn't learn your preferences or try to optimize what you see.

Why does this matter? In practice, letting the *date* decide removes the temptation to refresh until you get "the right verse." You meet each day's verse as given. This mirrors a contemplative principle: acceptance over preference.

### Bilingual from the Ground Up

The Diamond Sutra belongs equally to Chinese and English-speaking traditions. Daily Sutra treats both languages as first-class:
- Full Chinese chapter titles (品名) alongside English
- Both languages have equally curated explanations and meanings
- Not English-centric with Chinese as an afterthought

Switching languages mid-use is instant and persistent. The app re-renders with full parity.

### Menu Bar Presence (Non-Intrusive)

Daily Sutra is a companion, not a distraction. It appears in the menu bar—a subtle lotus icon—and opens on demand. No notifications pushing you into an app, no design trying to keep you inside longer.

This mirrors the philosophy: the verse should be a gentle companion to your morning, not a product fighting for your attention.

### Content Depth Without Overwhelm

The core view is fast: verse + explanation + blessing. Three minutes, tops.

But if you want deeper learning, tap "Full Text" to access:
- Classical Chinese translation (Kumārajīva, 5th century)
- Full English translation (Gemmell, 1912)
- Extensive scholarly commentary and annotations

This two-tier approach respects different use cases: the hurried morning reader and the scholar with an afternoon to spend.

## Who Made This?

Daily Sutra was created by a practitioner interested in Buddhist wisdom and contemplative practice. The app is not affiliated with any Buddhist organization or lineage.

The explanations and reflective meanings in the app are the author's own interpretations—not doctrinal claims, not the canonical sutra text, but a sincere effort to make the verses meaningful for contemporary English and Chinese readers.

## Technical Choices

- **Native macOS only** — no web app, no cross-platform compromise. macOS has excellent platforms for this kind of work (AppKit, SwiftUI, UserNotifications).
- **Local only** — no cloud sync, no accounts, no telemetry. All state lives in UserDefaults on your machine.
- **Deterministic data** — the date is the only input needed to regenerate any verse, forever. No database, no API calls, no central server required.
- **Open source** — everything is readable, forkable, and modifiable. You can audit the code, modify it, redistribute it.

## The Sutras: Diamond & Heart

Daily Sutra draws randomly from a combined pool of 42 contemplations: the 32 chapters of the **Diamond Sutra** (金剛般若波羅蜜經) and 10 curated sections of the **Heart Sutra** (般若波羅蜜多心經).

Both sacred texts teach the profound wisdom of prajñāpāramitā—the dissolution of fixed concepts and the insight that all forms are empty of separate, permanent selfhood. By presenting both sutras in a unified daily pool where origin tags recede into the background, the app invites readers to receive each day's verse purely on its own contemplative merits.

## Accessibility & Craft

- **Keyboard-first**: full navigation without mouse dependency (← / → to browse, T for today, ⌘C to copy, Esc to close).
- **VoiceOver & Screen Readers**: fully discrete button focus, localized labels, and clean semantic structure.
- **Reading Ambience**: optional warm paper / parchment tint (宣紙色調) for a soft, meditative morning atmosphere.
- **Light and dark mode**: automatically adapts to macOS appearance with organic cream and charcoal-amber warmth.
- **Font scaling**: 0.85× to 1.8× with live percentage feedback.
- **Bilingual**: English and Traditional Chinese (繁體中文) with 1-tap switching and full parity.

## Privacy

Daily Sutra collects no data. The app does not:
- Contact any server
- Log your activities
- Track which verses you read
- Send telemetry

Your favorites, font size, language preference, reading ambience, and notification settings are stored locally in UserDefaults. Only you can access them.

## License

Source code: **MIT License** — use freely, modify freely, redistribute freely.

Diamond Sutra and Heart Sutra classical texts: **Public domain** (Kumārajīva's 5th-century Chinese translation, Xuanzang's 7th-century Chinese translation, Gemmell's 1912 English translation).

Explanations, meanings, blessings, and app design: **MIT License** (author's original work).

## Acknowledgments

### Scholarship
- Kumārajīva (鳩摩羅什) for the classical Chinese translation of the Diamond Sutra (5th century)
- Xuanzang (玄奘) for the classical Chinese translation of the Heart Sutra (7th century)
- J. Thaddeus Gemmell for the English translation (1912)
- Modern Buddhist scholars whose work informs the app author's interpretations

### Community
- macOS developers and designers who pioneered accessible menu bar apps
- SwiftUI and AppKit documentation
- The open-source community that makes this possible

### Spiritual Lineage
- Both Theravada and Mahayana Buddhist traditions
- Teachers and practitioners who have kept these teachings alive for 1700+ years

---

**Daily Sutra v1.1.0** | Made with 🙏 for contemplation

If you find this app useful, consider:
- Sharing it with friends interested in Buddhist practice
- Supporting Buddhist organizations and scholarship
- Sitting down with the full texts and diving deeper
