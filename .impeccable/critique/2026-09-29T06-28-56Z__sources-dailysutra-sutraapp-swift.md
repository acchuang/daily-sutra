---
target: Sources/DailySutra/SutraApp.swift
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/acchuang/Project/diamond-sutra-bar/Sources/DailySutra/SutraApp.swift"
target_fingerprint: "sha256:8a133cccb1b5d2b1e31af8e78318fadb4e2c805bbd305855a5d53823379a2a76"
target_path: /Users/acchuang/Project/diamond-sutra-bar/Sources/DailySutra/SutraApp.swift
timestamp: 2026-09-29T06-28-56Z
slug: sources-dailysutra-sutraapp-swift
---
Method: dual-agent (A: 3469c435-e671-4479-8e72-126cc9ffc445 · B: 598b3eec-4c92-4304-a4cb-67c756330ebc)

### Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 3/4 | Good state binding for favorites/pin; zero visual feedback (no HUD or checkmark) on verse copy; no cue for distance from "Today" during date browsing. |
| 2 | Match System / Real World | 2/4 | Raw uppercase schema string `· DIAMOND` leaks DB model; duplicate "Meaning: / Explanation:" labels; system daemons in a spiritual contemplation space. |
| 3 | User Control and Freedom | 3/4 | Excellent keyboard shortcuts (←, →, T, Esc, ⌘C) and resizable panel; but date browser lacks an explicit "Back" button (requires re-clicking calendar icon). |
| 4 | Consistency and Standards | 2/4 | Two conflicting ellipsis menus (`ellipsis.circle` vs `ellipsis`); non-standard `pointingHand` cursor on desktop push buttons; italicized Traditional Chinese characters. |
| 5 | Error Prevention | 3/4 | Clamped calendar bounds (`...Date()`) and graceful notification permission handling; "Quit" in bottom menu lacks confirmation. |
| 6 | Recognition Rather Than Recall | 2/4 | 10 icon-only buttons in bottom bar with no text labels; header ellipsis menu conceals language selection with no current-language badge. |
| 7 | Flexibility and Efficiency | 3/4 | Keyboard accelerators are selection-aware; lacks progressive disclosure or customizable controls. |
| 8 | Aesthetic and Minimalist Design | 1/4 | Overcrowded dashboard (15 visible controls); clutters a sacred reading space with OS system toggles and login daemons. |
| 9 | Error Recovery | 3/4 | Clear notification denial alert with deep link to System Settings; clean fallback if `verses.json` is missing. |
| 10 | Help and Documentation | 2/4 | First-run modal wizard blocks immediate reading, but once dismissed, keyboard shortcuts and guidance cannot be retrieved anywhere. |
| **Total** | | **24/40** | **Acceptable (60%)** |

### Design Specificity Verdict

**Verdict:** *Category-Interchangeable Utility Shell Masking a Mindful Core.*

**LLM assessment:** While the core material (Kumārajīva's classical Chinese, Gemmell's translation, authored reflections, and dynamic weekday blessings) is deeply rooted in mindful Buddhist practice, the visual interface implemented in `SutraApp.swift` feels like a generic developer utility or system tray tool (akin to a clipboard manager or audio switcher) rather than a tranquil sanctuary for contemplation. The interface relies on Apple's standard `.regularMaterial` frosted gray glass with default SF Symbols. Administrative controls (`Launch at Login`, `Daily reminder` toggle, and time picker) are permanently embedded right under the scripture, forcing the user to confront OS plumbing during a morning spiritual pause. Furthermore, the app header violates its own core specification from `AGENTS.md` ("the app does not show which sutra a verse is from") by shouting `· DIAMOND` or `· HEART` in raw uppercase sans-serif.

**Deterministic scan:** `impeccable detect` returned 0 findings because the scanner targets web markup ASTs (JSX/HTML/CSS) rather than native Swift code. An isolated structural code audit revealed critical native defects:
1. Direct spec violation exposing `· \(v.sutra.uppercased())` in the header.
2. Accessibility blockage: toolbar buttons wrapped in `.accessibilityElement(children: .combine)` with a single label ("Navigation", "Collections", "Display"), hiding individual button actions from VoiceOver.
3. Unsynchronized global `NSCursor.push()` / `pop()` on `.onHover` that leaks cursor state and violates macOS desktop HIG.
4. Hardcoded English accessibility labels causing duplicate prefixing (`"Explanation: Explanation: ..."`) on Chinese text.
5. Asynchronous cancellation race condition in `DailyNotifier.reschedule()`.

**Visual overlays:** Skipped. `DailySutra` is a native macOS SwiftUI/AppKit desktop app (`NSStatusItem` + custom `NSPanel`); it does not render in a web browser canvas or expose a mutable DOM for script injection.

### Overall Impression
Daily Sutra's core text, bilingual parity, and deterministic date engine are genuinely sublime and respectful. However, the interface envelope treats the app like an administrative system utility—crowding the sacred verse with 15 simultaneous interactive elements, raw database keys, login daemons, and two competing ellipsis menus.

### What's Working
1. **Thoughtful Keyboard Architecture:** The local key monitor supporting `←` / `→` (prev/next), `T` (today), `Esc` (dismiss), and an intelligent `⌘C` implementation that defers to native selection copy when text is highlighted before copying the formatted verse is superb native macOS craft.
2. **Deterministic Depth & Bilingual Parity:** The date-driven pseudo-random distribution (`DailyPick.index`) paired with authentic Kumārajīva texts, Gemmell translations, and bespoke reflections gives the app deep spiritual legitimacy.
3. **Flexible Floating Panel with Pinning:** Moving from NSPopover to a movable, resizable `NSPanel` with `canBecomeKey = true` and `hidesOnDeactivate` bound to a pin toggle provides genuine utility without trapping the user.

### Priority Issues

- **[P1] Settings & OS plumbing cluttering the sacred reading space**
  - **Why it matters:** Seeing "Launch at Login" and "Daily reminder [08:00 AM]" on every launch destroys the calm, meditative atmosphere and creates cognitive noise.
  - **Fix:** Relocate background preferences (Launch at Login, Notifications, Notification Time) into a dedicated Settings sheet or unify them into the header menu. Keep the reading card exclusively focused on the verse.
  - **Suggested command:** `/impeccable distill`

- **[P1] Overloaded 10-button bottom toolbar violating working memory & breaking VoiceOver**
  - **Why it matters:** Cramming 10 icon buttons across 3 categories into a 320–400px bar creates visual chaos (15 total interactive controls on screen) and confuses users with unlabelled icons. Furthermore, wrapping them in `.accessibilityElement(children: .combine)` blocks VoiceOver users from interacting with individual buttons.
  - **Fix:** Redesign the footer into a serene, minimal bar featuring only navigation (← Today →) and a copy button with clear status feedback. Move date browsing, favorites, and text scaling into clean secondary surfaces or header actions, and remove the combined accessibility elements.
  - **Suggested command:** `/impeccable layout`

- **[P1] Spec violation: Sutra name exposed in header (`· DIAMOND` / `· HEART`)**
  - **Why it matters:** `AGENTS.md` explicitly specifies four separate times: *"The sutra a verse is from is not shown. No sutra name is shown. Uniform across Diamond and Heart so the sutra stays hidden."* Showing `· DIAMOND` violates the contemplative principle of drawing from a single unified wisdom pool.
  - **Fix:** Remove `· \(v.sutra.uppercased())` from `SutraApp.swift#L576` so only the chapter/section indicator remains.
  - **Suggested command:** `/impeccable clarify`

- **[P2] Visual, Typographic, and Copy Inconsistencies**
  - **Why it matters:** The UI displays duplicate labels (`Meaning:` directly followed by `Explanation:`), leaks uppercase database names, applies non-standard `.italic()` to Chinese characters, and splits options between two different ellipsis icons (`ellipsis.circle` in header vs `ellipsis` in footer).
  - **Fix:** Remove the redundant `"Explanation:"` prefix inside `VerseText.explanation` when rendered under `"Meaning:"`, replace `.italic()` with a lighter font weight for Chinese blessings, and consolidate language selection and utility actions into a single coherent menu.
  - **Suggested command:** `/impeccable typeset`

- **[P2] Intrusive modal onboarding with unlocalized strings**
  - **Why it matters:** A blocking 5-step modal wizard with a dark dimming scrim breaks the morning ritual upon first launch. Once dismissed, there is no way for users to review keyboard shortcuts or app information, and all strings are hardcoded in English.
  - **Fix:** Replace the modal overlay with gentle, non-blocking inline cues or a subtle first-run banner, localize all text into Traditional Chinese, and add a permanent "Keyboard Shortcuts & About" popover to the settings menu.
  - **Suggested command:** `/impeccable onboard`

### Persona Red Flags

- **Elena (Contemplative Morning Practitioner):**
  - Confronted by 15 interactive elements, including checkboxes for login daemons and notification alarms, shattering the morning quiet.
  - The footer feels like an IDE toolbar rather than a spiritual altar.
  - Copying the verse gives no visual feedback; she has to paste into Notes to verify it worked.
  - Sees raw technical text `· DIAMOND` breaking the timelessness of the verse.

- **Jordan (Confused First-Timer):**
  - Instantly hit with a 5-step modal wizard that forces multiple clicks before letting them see the app.
  - Confused by two different ellipsis menus (`ellipsis.circle` in header vs `ellipsis` in footer).
  - Encounters 10 mystery meat icon buttons with no text labels.
  - Clicking "Calendar" opens a full graphical month picker that completely displaces the verse, with no obvious "Back" button.

- **Sam (Accessibility & Keyboard User):**
  - Toolbar buttons are grouped with `.accessibilityElement(children: .combine)`, merging separate buttons into opaque groups like "Navigation" instead of allowing discrete VoiceOver traversal to "Previous Verse", "Today", or "Next Verse".
  - Hover states push a web-style `pointingHand` cursor, violating macOS platform guidelines and risking cursor stack desynchronization.
  - VoiceOver reads duplicate English prefixes (`"Explanation: Explanation: ..."`) on Chinese scripture text.

### Minor Observations
1. **Copy Feedback Vacuum:** No checkmark transition or HUD pill when verse is copied.
2. **Onboarding Localization:** Hardcoded English text in `OnboardingOverlay` with literal emoji `❤` ignores `AppLang.zh`.
3. **Empty Favorites State:** Simple string with no empty-state illustration or gentle guidance.
4. **Graphical DatePicker Sizing:** `.datePickerStyle(.graphical)` demands substantial vertical real estate and causes layout squishing in a 320px wide panel.
5. **History View Navigation:** Tapping "Browse by date" provides no explicit "Cancel" or "Back to Verse" button, requiring the user to tap the calendar icon again to dismiss.
6. **Notification Queue Race:** `DailyNotifier.reschedule()` triggers an asynchronous cancellation that can accidentally purge freshly scheduled notification requests.

### Questions to Consider
1. *What if the primary card contained strictly the verse, the reflection, and the blessing—moving all preferences, login settings, and font controls into a clean popover sheet?*
2. *Why does a daily contemplation tool require a 10-button toolbar when the core morning ritual is simply reading one verse and returning to the day?*
3. *Could the visual framing adopt subtle, warm paper/linen undertones and classic book typography, abandoning the cold, translucent developer-utility aesthetic?*
