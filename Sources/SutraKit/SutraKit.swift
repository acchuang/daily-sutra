import Foundation

public struct Verse: Codable, Identifiable {
    public let index: Int          // 1...N within its sutra
    public let sutra: String        // "diamond" | "heart"
    public var id: Int { index }
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

    public init(index: Int, sutra: String, titleZh: String, titleEn: String, zh: String, en: String,
                verseEn: String, verseZh: String, explEn: String, explZh: String, meaning: String, meaningZh: String) {
        self.index = index; self.sutra = sutra; self.titleZh = titleZh; self.titleEn = titleEn
        self.zh = zh; self.en = en; self.verseEn = verseEn; self.verseZh = verseZh
        self.explEn = explEn; self.explZh = explZh; self.meaning = meaning; self.meaningZh = meaningZh
    }
}

func sutraKitDiag(_ msg: String) {
    let line = "\(Date())  \(msg)\n"
    if let h = FileHandle(forWritingAtPath: "/tmp/dsb_diag.txt") {
        h.seekToEndOfFile(); h.write(Data(line.utf8)); h.closeFile()
    } else {
        try? line.write(toFile: "/tmp/dsb_diag.txt", atomically: true, encoding: .utf8)
    }
}

public enum VerseStore {
    public static func load() -> [Verse] {
        guard let url = Bundle.main.url(forResource: "verses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            sutraKitDiag("VerseStore: resource not found")
            return fallback()
        }
        do {
            return try JSONDecoder().decode([Verse].self, from: data)
        } catch {
            sutraKitDiag("VerseStore: decode failed: \(error)")
            return fallback()
        }
    }

    private static func fallback() -> [Verse] {
        [Verse(index: 0, sutra: "diamond", titleZh: "未載入", titleEn: "Not loaded",
               zh: "請確認 verses.json 已隨 app 打包。", en: "Ensure verses.json is bundled.",
               verseEn: "", verseZh: "", explEn: "", explZh: "", meaning: "", meaningZh: "")]
    }
}

/// Deterministic per-date pseudo-random verse pick — shared by the app and the
/// widget so both show the SAME verse on the same day (xorshift64 over YYYYMMDD).
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