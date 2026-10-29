import Foundation
import os

private let logger = Logger(subsystem: "com.acchuang.daily-sutra", category: "SutraKit")

public struct Verse: Codable, Identifiable, Equatable, Hashable {
    public let index: Int          // 1...N within its sutra
    public let sutra: String        // "diamond" | "heart"
    public var id: String { "\(sutra)_\(index)" }
    public let titleZh: String     // 品名 e.g. 法會因由分第一
    public let titleEn: String     // section label
    public let zh: String          // classical Chinese full passage (Kumārajīva / Xuanzang, PD)
    public let en: String          // PD English (Gemmell for diamond, Müller for heart)
    public let verseEn: String     // modern English verse (app author's paraphrase)
    public let verseZh: String     // authentic classical Chinese line from the section
    public let explEn: String      // plain-language explanation (English)
    public let explZh: String      // plain-language explanation (modern traditional Chinese)
    public let meaning: String     // reflective meaning (English, app author's commentary)
    public let meaningZh: String   // reflective meaning (modern traditional Chinese)
    public let blessing: String        // closing blessing (English), with {weekday} placeholder
    public let blessingZh: String      // closing blessing (modern traditional Chinese), with {weekday} placeholder
    public let sourceEn: String?       // classical text + translation credit, shown in Full Text
    public let sourceZh: String?

    public init(index: Int, sutra: String, titleZh: String, titleEn: String, zh: String, en: String,
                verseEn: String, verseZh: String, explEn: String, explZh: String, meaning: String, meaningZh: String,
                blessing: String = "", blessingZh: String = "",
                sourceEn: String? = nil, sourceZh: String? = nil) {
        self.index = index; self.sutra = sutra; self.titleZh = titleZh; self.titleEn = titleEn
        self.zh = zh; self.en = en; self.verseEn = verseEn; self.verseZh = verseZh
        self.explEn = explEn; self.explZh = explZh; self.meaning = meaning; self.meaningZh = meaningZh
        self.blessing = blessing; self.blessingZh = blessingZh
        self.sourceEn = sourceEn; self.sourceZh = sourceZh
    }
}

public enum VerseStore {
    public static func load(from bundle: Bundle = .main) -> [Verse] {
        guard let url = bundle.url(forResource: "verses", withExtension: "json") else {
            logger.warning("VerseStore: resource 'verses.json' not found in bundle \(bundle)")
            return fallback()
        }
        return load(from: url)
    }

    public static func load(from url: URL) -> [Verse] {
        guard let data = try? Data(contentsOf: url) else {
            logger.warning("VerseStore: could not read data from \(url)")
            return fallback()
        }
        do {
            return try JSONDecoder().decode([Verse].self, from: data)
        } catch {
            logger.error("VerseStore: decode failed: \(error.localizedDescription)")
            return fallback()
        }
    }

    private static func fallback() -> [Verse] {
        [Verse(index: 0, sutra: "diamond", titleZh: "未載入", titleEn: "Not loaded",
               zh: "請確認 verses.json 已隨 app 打包。", en: "Ensure verses.json is bundled.",
               verseEn: "", verseZh: "", explEn: "", explZh: "", meaning: "", meaningZh: "")]
    }
}

/// Display text for a verse in one language. The panel, the favorites list and
/// the clipboard all render through this, so a wording change lands in one place.
public struct VerseText {
    public let zh: Bool

    public init(zh: Bool) { self.zh = zh }

    /// The pull-quote: the classical line in 中, the modern verse (curly-quoted) in EN.
    public func quote(_ v: Verse) -> String {
        zh ? v.verseZh : "\u{201C}\(v.verseEn)\u{201D}"
    }

    /// Single-line form for list rows.
    public func firstLine(_ v: Verse) -> String {
        (zh ? v.verseZh : v.verseEn).components(separatedBy: "\n").first ?? ""
    }

    /// Explanation merged with the reflection; empty when the verse has neither.
    public func explanation(_ v: Verse) -> String {
        let expl = zh ? v.explZh : v.explEn
        let meaning = zh ? v.meaningZh : v.meaning
        let body = expl + (meaning.isEmpty ? "" : (expl.isEmpty ? "" : " ") + meaning)
        if body.isEmpty { return "" }
        return zh ? "解釋：\(body)" : "Explanation: \(body)"
    }

    /// Credit for the classical text + translation shown in Full Text.
    public func source(_ v: Verse) -> String {
        (zh ? v.sourceZh : v.sourceEn) ?? ""
    }

    public var commentaryNote: String {
        zh ? "解說與祝福：AI 輔助撰寫，由作者審閱" : "Paraphrase, commentary and blessings: AI-assisted, author-reviewed"
    }

    public func weekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: zh ? "zh_TW" : "en_US")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    public func title(_ v: Verse?, on date: Date) -> String {
        let day = weekday(date)
        guard let v else { return day }
        return zh ? "\(day) — 第\(v.index)章" : "\(day) — Chapter \(v.index)"
    }

    public func blessing(_ v: Verse?, on date: Date) -> String {
        let day = weekday(date)
        if let v {
            let raw = zh ? v.blessingZh : v.blessing
            if !raw.isEmpty { return raw.replacingOccurrences(of: "{weekday}", with: day) }
        }
        return zh ? "願你\(day)輕安。🙏" : "May your \(day) be light. 🙏"
    }

    public func clipboard(_ v: Verse, on date: Date) -> String {
        let expl = explanation(v)
        return [title(v, on: date), quote(v), expl, blessing(v, on: date)]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }
}

/// Deterministic per-date verse pick — a pure function of the local calendar
/// date and the pool size. Days are grouped into cycles of `count`; each cycle
/// is a seeded shuffle of the pool, so every verse appears once per cycle and
/// none repeats on consecutive days.
/// Stable within an app version: changing the pool size reshuffles every date.
/// The landing page simulator mirrors this exactly; keep them in step.
public enum DailyPick {
    public static func index(count: Int, for date: Date = Date()) -> Int {
        guard count > 0 else { return 0 }
        let c = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let day = dayNumber(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
        let cycle = floorDiv(day, count)
        var order = shuffled(cycle: cycle, count: count)
        // Never repeat a verse across the cycle seam. The swap only touches
        // positions 0 and 1, so the previous cycle's last slot is never moved.
        if count > 2, order[0] == shuffled(cycle: cycle - 1, count: count)[count - 1] {
            order.swapAt(0, 1)
        }
        return order[day - cycle * count]
    }

    private static func shuffled(cycle: Int, count: Int) -> [Int] {
        var seed = UInt64(bitPattern: Int64(cycle))
        var order = Array(0..<count)
        for i in stride(from: count - 1, to: 0, by: -1) {
            order.swapAt(i, Int(splitmix64(&seed) % UInt64(i + 1)))
        }
        return order
    }

    /// Days since 1970-01-01 in the proleptic Gregorian calendar (Hinnant's civil-days algorithm).
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDiv(y, 400)
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    private static func splitmix64(_ state: inout UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}