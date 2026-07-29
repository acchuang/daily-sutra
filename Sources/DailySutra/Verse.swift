import Foundation
import SwiftUI

struct Verse: Codable, Identifiable {
    let index: Int          // 1...N within its sutra
    let sutra: String        // "diamond" | "heart"
    var id: Int { index }
    let titleZh: String     // 品名 e.g. 法會因由分第一
    let titleEn: String     // section label
    let zh: String          // classical Chinese full passage (Kumārajīva / Xuanzang, PD)
    let en: String          // PD English (Gemmell for diamond) or paraphrase (heart)
    let verseEn: String     // modern English verse (app author's paraphrase)
    let verseZh: String     // authentic classical Chinese line from the section
    let explEn: String      // plain-language explanation (English)
    let explZh: String      // plain-language explanation (modern traditional Chinese)
    let meaning: String     // reflective meaning (English, app author's commentary)
    let meaningZh: String   // reflective meaning (modern traditional Chinese)
}

enum AppLang: String, CaseIterable {
    case en, zh
    var label: String { self == .en ? "EN" : "中" }
}

enum VerseStore {
    static func load() -> [Verse] {
        guard let url = Bundle.main.url(forResource: "verses", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            diag("VerseStore: resource not found")
            return fallback()
        }
        do {
            return try JSONDecoder().decode([Verse].self, from: data)
        } catch {
            diag("VerseStore: decode failed: \(error)")
            return fallback()
        }
    }

    private static func fallback() -> [Verse] {
        [Verse(index: 0, sutra: "diamond", titleZh: "未載入", titleEn: "Not loaded",
               zh: "請確認 verses.json 已隨 app 打包。", en: "Ensure verses.json is bundled.",
               verseEn: "", verseZh: "", explEn: "", explZh: "", meaning: "", meaningZh: "")]
    }
}