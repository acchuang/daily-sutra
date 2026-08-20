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