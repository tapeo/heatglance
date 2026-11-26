import Foundation

#if canImport(UserNotifications)
import UserNotifications

public final class Notifier: @unchecked Sendable {
    private let center = UNUserNotificationCenter.current()

    public init() {}

    public func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    public func send(_ payload: NotificationPayload) {
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default
        content.categoryIdentifier = payload.category.rawValue
        content.userInfo = payload.userInfo
        let request = UNNotificationRequest(
            identifier: payload.identifier,
            content: content,
            trigger: nil
        )
        center.add(request) { _ in }
    }

    public func updateCategories(_ categories: Set<UNNotificationCategory>) {
        center.setNotificationCategories(categories)
    }

    public func scheduleWeeklySummary(enabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: ["heatglance.weekly"])
        guard enabled else {
            return
        }
        var components = DateComponents()
        components.weekday = 2
        components.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Your week with HeatGlance"
        content.body = "Open History to see what kept your Mac busy."
        content.categoryIdentifier = NotificationCategory.weeklySummary.rawValue
        center.add(UNNotificationRequest(identifier: "heatglance.weekly", content: content, trigger: trigger)) { _ in }
    }
}
#endif
