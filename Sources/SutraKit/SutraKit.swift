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
    public let en: String          // PD English (Gemmell for diamond) or paraphrase (heart)
    public let verseEn: String     // modern English verse (app author's paraphrase)
    public let verseZh: String     // authentic classical Chinese line from the section
    public let explEn: String      // plain-language explanation (English)
    public let explZh: String      // plain-language explanation (modern traditional Chinese)
    public let meaning: String     // reflective meaning (English, app author's commentary)
    public let meaningZh: String   // reflective meaning (modern traditional Chinese)
    public let blessing: String        // closing blessing (English), with {weekday} placeholder
    public let blessingZh: String      // closing blessing (modern traditional Chinese), with {weekday} placeholder

    public init(index: Int, sutra: String, titleZh: String, titleEn: String, zh: String, en: String,
                verseEn: String, verseZh: String, explEn: String, explZh: String, meaning: String, meaningZh: String,
                blessing: String = "", blessingZh: String = "") {
        self.index = index; self.sutra = sutra; self.titleZh = titleZh; self.titleEn = titleEn
        self.zh = zh; self.en = en; self.verseEn = verseEn; self.verseZh = verseZh
        self.explEn = explEn; self.explZh = explZh; self.meaning = meaning; self.meaningZh = meaningZh
        self.blessing = blessing; self.blessingZh = blessingZh
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

/// Deterministic per-date pseudo-random verse pick — a pure function of the
/// local calendar date, so any date's verse can be recomputed without history.
public enum DailyPick {
    public static func index(count: Int, for date: Date = Date()) -> Int {
        guard count > 0 else { return 0 }
        let cal = Calendar(identifier: .gregorian)
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let y = c.year ?? 0, m = c.month ?? 0, d = c.day ?? 0
        var s = UInt64(bitPattern: Int64(y * 10000 + m * 100 + d))
        s ^= s << 13; s ^= s >> 7; s ^= s << 17   // xorshift64
        return Int(s % UInt64(count))
    }
}