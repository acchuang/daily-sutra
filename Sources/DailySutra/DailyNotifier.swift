import Foundation
import UserNotifications
import os
import SutraKit

/// Daily verse reminder.
///
/// The pick is a pure function of the date, so instead of one repeating
/// notification with a generic body, the next two weeks are queued as separate
/// requests carrying each day's actual verse. Whenever the app is open it tops
/// the queue back up, which is enough for a menu bar app that runs all day.
enum DailyNotifier {
    private static let logger = Logger(subsystem: "com.acchuang.daily-sutra", category: "Notifier")
    private static let idPrefix = "daily-verse-"
    private static let horizonDays = 14

    /// UNUserNotificationCenter traps when the process has no bundle — true for
    /// `swift run` during development, false for the assembled .app.
    private static var isBundled: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestAuthorization() async -> Bool {
        guard isBundled else { return false }
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.error("authorization failed: \(error.localizedDescription)")
            return false
        }
    }

    static func cancelAll() {
        guard isBundled else { return }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// Replaces the queue with one notification per day at `hour:minute`,
    /// starting with the next occurrence.
    static func reschedule(verses: [Verse], text: VerseText, hour: Int, minute: Int) {
        guard isBundled, !verses.isEmpty else { return }
        cancelAll()

        let cal = Calendar.current
        let now = Date()
        let center = UNUserNotificationCenter.current()

        for dayOffset in 0...horizonDays {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: now),
                  let fire = cal.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  fire > now                       // today's slot may already have passed
            else { continue }

            let verse = verses[DailyPick.index(count: verses.count, for: fire)]
            let content = UNMutableNotificationContent()
            content.title = text.title(verse, on: fire)
            content.body = text.quote(verse)
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false)
            let id = idPrefix + ISO8601DateFormatter.dayFormatter.string(from: fire)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger)) { error in
                if let error { logger.error("schedule failed: \(error.localizedDescription)") }
            }
        }
    }
}

private extension ISO8601DateFormatter {
    static let dayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
