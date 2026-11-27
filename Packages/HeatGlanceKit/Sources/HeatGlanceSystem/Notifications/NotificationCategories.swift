import Foundation

#if canImport(UserNotifications)
import UserNotifications

public enum NotificationCategory: String, Sendable {
    case processAlert = "process_alert"
    case fileAlert = "file_alert"
    case systemAlert = "system_alert"
    case protectionAlert = "protection_alert"
    case protectionReturn = "protection_return"
    case leakAlert = "leak_alert"
    case weeklySummary = "weekly_summary"
}

public enum NotificationAction: String, Sendable {
    case suspend = "heatglance.suspend"
    case quit = "heatglance.quit"
    case ignoreHour = "heatglance.ignore_hour"
    case resumeAll = "heatglance.resume_all"
    case turnOffProtection = "heatglance.turn_off_protection"
    case sleepDisplay = "heatglance.sleep_display"
    case showInFinder = "heatglance.show_in_finder"
    case moveToTrash = "heatglance.move_to_trash"
    case ignoreFolder = "heatglance.ignore_folder"
    case openHeatGlance = "heatglance.open"
    case relaunch = "heatglance.relaunch"
    case keepPaused = "heatglance.keep_paused"
    case openSummary = "heatglance.open_summary"
}

public enum NotificationCategories {
    public static func make() -> Set<UNNotificationCategory> {
        let processActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.suspend.rawValue, title: "Suspend", options: []),
            UNNotificationAction(identifier: NotificationAction.quit.rawValue, title: "Quit", options: [.destructive]),
            UNNotificationAction(identifier: NotificationAction.sleepDisplay.rawValue, title: "Sleep display", options: []),
            UNNotificationAction(identifier: NotificationAction.ignoreHour.rawValue, title: "Ignore for 1 hour", options: []),
        ]
        let fileActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.showInFinder.rawValue, title: "Show in Finder", options: []),
            UNNotificationAction(identifier: NotificationAction.moveToTrash.rawValue, title: "Move to Trash", options: [.destructive]),
            UNNotificationAction(identifier: NotificationAction.ignoreFolder.rawValue, title: "Ignore this folder", options: []),
        ]
        let systemActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.openHeatGlance.rawValue, title: "Open HeatGlance", options: [.foreground]),
        ]
        let protectionActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.resumeAll.rawValue, title: "Resume all", options: []),
            UNNotificationAction(identifier: NotificationAction.turnOffProtection.rawValue, title: "Turn off protection", options: [.destructive]),
        ]
        let returnActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.resumeAll.rawValue, title: "Resume all", options: []),
            UNNotificationAction(identifier: NotificationAction.keepPaused.rawValue, title: "Keep paused", options: []),
        ]
        let leakActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.relaunch.rawValue, title: "Relaunch", options: []),
            UNNotificationAction(identifier: NotificationAction.quit.rawValue, title: "Quit", options: [.destructive]),
            UNNotificationAction(identifier: NotificationAction.ignoreHour.rawValue, title: "Ignore for 1 hour", options: []),
        ]
        let summaryActions: [UNNotificationAction] = [
            UNNotificationAction(identifier: NotificationAction.openSummary.rawValue, title: "Open summary", options: [.foreground]),
        ]

        return [
            UNNotificationCategory(identifier: NotificationCategory.processAlert.rawValue, actions: processActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.fileAlert.rawValue, actions: fileActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.systemAlert.rawValue, actions: systemActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.protectionAlert.rawValue, actions: protectionActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.protectionReturn.rawValue, actions: returnActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.leakAlert.rawValue, actions: leakActions, intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.weeklySummary.rawValue, actions: summaryActions, intentIdentifiers: [], options: []),
        ]
    }
}

public struct NotificationPayload: Sendable {
    public let category: NotificationCategory
    public let title: String
    public let body: String
    public let userInfo: [String: String]
    public let identifier: String
    public let logsAsEvent: Bool

    public init(
        category: NotificationCategory,
        title: String,
        body: String,
        userInfo: [String: String] = [:],
        identifier: String = UUID().uuidString,
        logsAsEvent: Bool = true
    ) {
        self.category = category
        self.title = title
        self.body = body
        self.userInfo = userInfo
        self.identifier = identifier
        self.logsAsEvent = logsAsEvent
    }
}
#endif
