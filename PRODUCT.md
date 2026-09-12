# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS (menu bar app, native)

## Users

Contemplative practitioners and curious readers interested in Buddhist wisdom. Daily users seeking morning guidance; occasional browsers exploring classical texts. Bilingual readers (English and Traditional Chinese).

## Product Purpose

Daily Sutra delivers one verse from the Diamond Sutra each day, paired with modern explanation and reflective meaning. It makes Buddhist wisdom accessible and memorable through:
- **Deterministic daily picks**: Same verse every day, everywhere (xorshift64 on date)
- **Bilingual support**: Classical and modern Chinese alongside English
- **Contextual depth**: Verse + explanation + reflective meaning + blessing
- **Optional deep learning**: Access full classical translations and extensive commentary
- **Non-intrusive presence**: Menu bar app, floating panel, appears when needed

Success: Users develop a sustainable daily practice; return daily for verse + meaning; gradually explore full classical texts.

## Positioning

Daily Sutra is a contemplative companion app, not a Buddhist teaching app. It assumes the user brings their own practice and curiosity. The core insight: one verse per day, curated with depth and bilingual care, creates space for reflection without overwhelm. The mechanism is simple (deterministic daily pick) but philosophically sound (no recommendation algorithm, only calendar and mathematics).

## Operating Context

**Morning ritual**: User opens menu bar icon, reads verse and meaning, closes panel. Time: 2-3 minutes.

**Browsing**: User clicks history/calendar, jumps to past dates, explores verses. Discovers chapters and structure.

**Deep dives**: User clicks "Full Text," reads classical translation and extensive commentary. Time: 10-30 minutes.

**Notifications**: Optional daily reminder at user-selected time (default 8am). Opens panel on click.

**Settings**: Language toggle, font size (0.85×–1.8×), launch at login, notification toggle + time.

Bilingual users switch languages mid-session; app maintains state and re-renders on change.

## Capabilities and Constraints

**Implemented**:
- 32 Diamond Sutra chapters (full texts, translations, commentary, explanations, meanings, blessings)
- Deterministic daily verse selection
- Bilingual display (EN/中) with persistent preference
- Font scaling (0.85×–1.8×) with UserDefaults persistence
- Favorites system (heart icon, scrollable list)
- Date browsing (calendar picker, jump to any past date)
- Keyboard shortcuts (←/→ navigate, T today, Cmd+C copy, Esc close)
- Daily notifications with configurable time
- Launch at login toggle
- Pin/unpin panel (stays visible across app switches when pinned)
- Copy formatted verse (title, verse, explanation, blessing, weekday)
- Full text toggle (classical translations + commentary)
- Onboarding flow (5-step first-run intro)

**Constraints**:
- Menu bar app only (floating panel, not windowed)
- macOS 14+ only
- No cloud sync, no user accounts
- No persistence of browse history (only favorites and date jumps)
- Fixed panel dimensions (400×560 resizable, min 320×400)
- Single-user local state (UserDefaults)

**Terminology**:
- "Verse" = the modern English paraphrase or classical Chinese line
- "Meaning" = reflective commentary (app author's interpretation)
- "Explanation" = plain-language clarification
- "Blessing" = personalized closing with weekday

## Brand Commitments

**Name**: Daily Sutra (also: diamond-sutra-bar, the repo name is a reference to the spiritual bar/threshold)

**Voice**: Contemplative, respectful, simple. No marketing speak, no user-facing "features," only what the app does.

**Bilingual identity**: Equally English and Traditional Chinese. Not translation + original, but parallel articulation. Chinese chapter titles (品名) preserved alongside English.

**Philosophical stance**: Theravada/Mahayana scholarship respected; app is companion to practice, not doctrine.

**Visual identity** (existing):
- App icon: Currently generic (template)
- Menu bar icon: Currently generic (template)
- No explicit color palette beyond system (light/dark)
- Typography: Serif for verses (classical weight), sans for UI

**Existing assets**:
- 32 Diamond Sutra chapters (verses.json, 217.7KB, curated)
- AppIcon.icns, MenubarIcon.png (both placeholders)
- Swift/SwiftUI codebase (native macOS, no web dependencies)

## Evidence on Hand

- **Real content**: Full Diamond Sutra, classical Chinese text (Kumārajīva), English translation (Gemmell, public domain), plus app author's explanations and reflective meanings. 32 chapters, complete.
- **Real users**: Unknown; app is open-source, GitHub repo shows interest but no public metrics.
- **Design maturity**: UI is functional, no incumbent visual world beyond system defaults.
- **Code quality**: Well-structured (VerseViewModel, single source of truth for display text, proper state management).

## Product Principles

1. **One verse per day, deterministically**: No recommendations, no personalization algorithms. The same verse every day everywhere, grounded in simple mathematics (date XOR).

2. **Bilingual from the foundation**: Not English with Chinese as an afterthought. Both languages are first-class; chapter titles, blessings, explanations all exist in both.

3. **Depth without overwhelm**: Core verse is quick (2-3 min). Full texts available optionally. Notifications are opt-in, not aggressive.

4. **Menu bar presence, not window focus**: App serves the morning ritual, not a distraction. Appears, delivers, disappears.

5. **Contemplative design**: Serif fonts for classical text, generous whitespace, readable hierarchy. Supports reflection, not speed.

## Accessibility & Inclusion

- Keyboard-first (arrow keys, shortcuts, no mouse required)
- Screen reader support (accessibility labels on buttons and verse sections)
- Dynamic Type baseline (font scaling 0.85×–1.8×, though explicit DynamicType integration is a known gap)
- Color contrast (system colors, respects light/dark)
- Bilingual: English + Traditional Chinese (no simplified, no RTL)
- macOS 14+ accessibility features (Reduce Motion, etc.)

Known gap: Dynamic Type not explicitly wired; current scaling is manual.
