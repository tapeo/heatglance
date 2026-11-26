import AppKit
import UserNotifications

import HeatGlanceCore
import HeatGlanceSystem

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories(NotificationCategories.make())
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        Monitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Monitor.shared.shutdown()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        let action = response.actionIdentifier
        let rule = info["rule"] as? String
        let group = info["group"] as? String

        switch action {
        case NotificationAction.resumeAll.rawValue:
            await SuspendedProcessRegistry().resumeAll(origin: nil)
            await MainActor.run {
                NotificationCenter.default.post(name: .heatGlanceResumeAll, object: nil)
            }
        case NotificationAction.turnOffProtection.rawValue:
            await MainActor.run {
                NotificationCenter.default.post(name: .heatGlanceTurnOffProtection, object: nil)
            }
        case NotificationAction.ignoreHour.rawValue:
            guard let rule else {
                return
            }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .heatGlanceIgnoreRule,
                    object: nil,
                    userInfo: ["rule": rule]
                )
            }
        case NotificationAction.sleepDisplay.rawValue:
            _ = await DisplaySleeper.sleepDisplay()
        case NotificationAction.suspend.rawValue, NotificationAction.quit.rawValue:
            guard let group else {
                return
            }
            await MainActor.run {
                NotificationCenter.default.post(
                    name: .heatGlanceProcessAction,
                    object: nil,
                    userInfo: ["group": group, "action": action]
                )
            }
        default:
            await MainActor.run {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
}

extension Notification.Name {
    static let heatGlanceTurnOffProtection = Notification.Name("heatglance.turnOffProtection")
    static let heatGlanceIgnoreRule = Notification.Name("heatglance.ignoreRule")
    static let heatGlanceProcessAction = Notification.Name("heatglance.processAction")
    static let heatGlanceResumeAll = Notification.Name("heatglance.resumeAll")
}
