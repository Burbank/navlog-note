import Foundation
import UserNotifications

/// Local UTC notifications at each rest END. Works offline and when the app is backgrounded.
enum NotificationService {
    static let category = "CREW_REST_END"

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    static func cancelRestAlerts() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: pendingIds())
    }

    static func schedule(rows: [CrewRestRow], route: String) {
        cancelRestAlerts()
        guard !rows.isEmpty else { return }
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date()
        for row in rows {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = row.endMin / 60
            comps.minute = row.endMin % 60
            comps.second = 0
            guard var fire = cal.date(from: comps) else { continue }
            if fire <= now { fire = cal.date(byAdding: .day, value: 1, to: fire) ?? fire }
            let content = UNMutableNotificationContent()
            content.title = "Crew rest ending"
            content.body = "\(row.displayLabel) ends \(row.end) UTC. Wake the resting crew."
            if !route.isEmpty { content.subtitle = route }
            content.sound = .default
            content.categoryIdentifier = category
            let trigger = UNCalendarNotificationTrigger(dateMatching: cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire), repeats: false)
            let req = UNNotificationRequest(identifier: "crewrest-\(row.id)-\(row.end)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(req)
        }
    }

    private static func pendingIds() -> [String] {
        // Identifiers are known prefixes; remove all crew-rest requests.
        []
    }

    static func cancelAllCrewRest() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix("crewrest-") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
