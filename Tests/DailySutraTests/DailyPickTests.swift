import XCTest
import SutraKit

/// Self-check for the only non-trivial logic in the app: the deterministic
/// daily verse pick. Run with `swift test`.
final class DailyPickTests: XCTestCase {
    private let count = 42

    func testDeterministicForSameDate() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)   // fixed, arbitrary
        let i1 = DailyPick.index(count: count, for: d)
        let i2 = DailyPick.index(count: count, for: d)
        XCTAssertEqual(i1, i2, "same date must yield the same index")
        XCTAssertTrue((0..<count).contains(i1), "index must be within the pool")
    }

    func testNegativeSeedStillInBounds() {
        // xorshift64 starts from a signed Int64 bit pattern; a date far in the
        // past produces a negative seed. The result must still be a valid index.
        let d = Date(timeIntervalSince1970: -1_000_000_000)
        let i = DailyPick.index(count: count, for: d)
        XCTAssertTrue((0..<count).contains(i), "negative-seed date out of bounds")
    }

    func testPicksAcrossAYearCoverThePool() {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        var seen = Set<Int>()
        for dayOffset in 0..<365 {
            let d = cal.date(byAdding: .day, value: dayOffset, to: base)!
            seen.insert(DailyPick.index(count: count, for: d))
        }
        // A good daily picker should reach most of the pool over a year;
        // if it collapsed to a handful of values, the seeding would be broken.
        XCTAssertGreaterThan(seen.count, count / 2, "a year of picks should cover most of the pool")
    }

    func testAdjacentDaysUsuallyDiffer() {
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        var sameAsPrevious = 0
        var prev = DailyPick.index(count: count, for: base)
        for dayOffset in 1..<365 {
            let d = cal.date(byAdding: .day, value: dayOffset, to: base)!
            let cur = DailyPick.index(count: count, for: d)
            if cur == prev { sameAsPrevious += 1 }
            prev = cur
        }
        // Consecutive identical picks should be rare; a high count would mean
        // the day-to-day seeding barely moves.
        XCTAssertLessThan(sameAsPrevious, 20, "too many adjacent-day repeats")
    }

    func testVerseIDUniquenessAndJSONValidation() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let rootURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let jsonURL = rootURL.appendingPathComponent("Sources/DailySutra/Resources/verses.json")
        let verses = VerseStore.load(from: jsonURL)

        XCTAssertEqual(verses.count, 42, "Should load all 42 verses (32 Diamond + 10 Heart)")

        let ids = verses.map { $0.id }
        let uniqueIDs = Set(ids)
        XCTAssertEqual(ids.count, uniqueIDs.count, "Every verse must have a unique ID across the entire pool")

        let diamondVerses = verses.filter { $0.sutra == "diamond" }
        let heartVerses = verses.filter { $0.sutra == "heart" }
        XCTAssertEqual(diamondVerses.count, 32, "Expected 32 Diamond Sutra chapters")
        XCTAssertEqual(heartVerses.count, 10, "Expected 10 Heart Sutra sections")

        for verse in verses {
            XCTAssertFalse(verse.id.isEmpty, "ID cannot be empty")
            XCTAssertFalse(verse.zh.isEmpty, "Classical Chinese passage cannot be empty: \(verse.id)")
            XCTAssertFalse(verse.verseZh.isEmpty, "Classical Chinese verse line cannot be empty: \(verse.id)")
            XCTAssertFalse(verse.verseEn.isEmpty, "English verse line cannot be empty: \(verse.id)")
            XCTAssertFalse(verse.explZh.isEmpty, "Chinese explanation cannot be empty: \(verse.id)")
            XCTAssertFalse(verse.explEn.isEmpty, "English explanation cannot be empty: \(verse.id)")
        }
    }
}
/// VerseText is the single source of truth for rendered verse text — the panel,
/// the favorites list and the clipboard all go through it.
final class VerseTextTests: XCTestCase {
    private let v = Verse(
        index: 3, sutra: "diamond", titleZh: "大乘正宗分", titleEn: "Great Vehicle",
        zh: "所有一切眾生之類", en: "All living beings",
        verseEn: "Lead every being to peace, then know\nno being was led.",
        verseZh: "應如是降伏其心",
        explEn: "Help without keeping score.", explZh: "幫忙不記帳。",
        meaning: "The helper dissolves.", meaningZh: "助人者亦空。",
        blessing: "May your {weekday} be spacious. 🌿", blessingZh: "願你{weekday}寬廣。🌿")

    private let monday = Calendar(identifier: .gregorian)
        .date(from: DateComponents(year: 2024, month: 1, day: 1))!

    func testQuoteAndFirstLine() {
        XCTAssertEqual(VerseText(zh: true).quote(v), "應如是降伏其心", "中 quotes the classical line bare")
        XCTAssertTrue(VerseText(zh: false).quote(v).hasPrefix("\u{201C}"), "EN verse is curly-quoted")
        XCTAssertEqual(VerseText(zh: false).firstLine(v), "Lead every being to peace, then know",
                       "list rows take only the first line")
    }

    func testExplanationMergesMeaning() {
        XCTAssertEqual(VerseText(zh: false).explanation(v),
                       "Explanation: Help without keeping score. The helper dissolves.")
        XCTAssertEqual(VerseText(zh: true).explanation(v), "解釋：幫忙不記帳。 助人者亦空。")
    }

    func testEmptyExplanationYieldsNoLabel() {
        let bare = Verse(index: 1, sutra: "heart", titleZh: "", titleEn: "", zh: "", en: "",
                         verseEn: "x", verseZh: "x", explEn: "", explZh: "", meaning: "", meaningZh: "")
        XCTAssertEqual(VerseText(zh: false).explanation(bare), "",
                       "no explanation must not render a dangling 'Explanation:' label")
    }

    func testWeekdayFollowsTheGivenDate() {
        XCTAssertEqual(VerseText(zh: false).title(v, on: monday), "Monday — Chapter 3")
        XCTAssertEqual(VerseText(zh: false).blessing(v, on: monday), "May your Monday be spacious. 🌿")
        XCTAssertEqual(VerseText(zh: true).title(v, on: monday), "星期一 — 第3章")
    }

    func testClipboardSkipsEmptySections() {
        let bare = Verse(index: 1, sutra: "heart", titleZh: "", titleEn: "", zh: "", en: "",
                         verseEn: "x", verseZh: "x", explEn: "", explZh: "", meaning: "", meaningZh: "")
        let out = VerseText(zh: false).clipboard(bare, on: monday)
        XCTAssertFalse(out.contains("\n\n\n"), "an empty section must not leave a blank gap")
        XCTAssertTrue(out.contains("May your Monday be light."), "falls back to the default blessing")
    }
}

/// VerseStore loading and fallback behavior.
final class VerseStoreTests: XCTestCase {
    func testLoadFromValidJSON() {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let rootURL = testFileURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let jsonURL = rootURL.appendingPathComponent("Sources/DailySutra/Resources/verses.json")
        let verses = VerseStore.load(from: jsonURL)
        XCTAssertGreaterThan(verses.count, 0, "should load verses from valid JSON")
        XCTAssertFalse(verses[0].id.isEmpty, "loaded verses should have valid IDs")
    }

    func testFallbackOnInvalidPath() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/verses.json")
        let verses = VerseStore.load(from: invalidURL)
        XCTAssertEqual(verses.count, 1, "fallback provides a single placeholder verse")
        XCTAssertEqual(verses[0].id, "diamond_0", "fallback verse has placeholder ID")
    }

    func testFallbackOnMissingResource() {
        // Bundle.main.url returns nil for missing resources; VerseStore should handle gracefully
        let verses = VerseStore.load(from: Bundle(for: type(of: self)))
        XCTAssertEqual(verses.count, 1, "should return fallback on missing resource")
    }
}

/// Edge cases and malformed data handling.
final class VerseEdgeCasesTests: XCTestCase {
    func testEmptyVersePoolStillReturnsValidIndex() {
        let index = DailyPick.index(count: 0, for: Date())
        XCTAssertEqual(index, 0, "empty pool should return 0")
    }

    func testSingleVerseAlwaysReturnsZero() {
        for day in 0..<365 {
            let d = Calendar(identifier: .gregorian).date(byAdding: .day, value: day, to: Date())!
            let i = DailyPick.index(count: 1, for: d)
            XCTAssertEqual(i, 0, "single verse must always return index 0")
        }
    }

    func testLargeVersePoolDistribution() {
        let pool = 1000
        let cal = Calendar(identifier: .gregorian)
        let base = cal.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        var indices = Set<Int>()
        for day in 0..<1000 {
            let d = cal.date(byAdding: .day, value: day, to: base)!
            indices.insert(DailyPick.index(count: pool, for: d))
        }
        XCTAssertGreaterThan(indices.count, pool / 2, "1000 days should cover >50% of a 1000-verse pool")
    }

    func testVerseWithMultilineContent() {
        let v = Verse(index: 1, sutra: "diamond", titleZh: "", titleEn: "",
                      zh: "line1\nline2", en: "line1\nline2",
                      verseEn: "verse line 1\nverse line 2", verseZh: "詩行一\n詩行二",
                      explEn: "explanation 1\nexplanation 2", explZh: "解釋1\n解釋2",
                      meaning: "meaning 1\nmeaning 2", meaningZh: "意義1\n意義2")
        let text = VerseText(zh: false)
        XCTAssertTrue(text.quote(v).contains("\n"), "multiline verse should preserve newlines")
        let first = text.firstLine(v)
        XCTAssertFalse(first.contains("\n"), "firstLine should extract only first line")
    }
}
