import Foundation

import HeatGlanceCore
import HeatGlanceSystem

extension Monitor {
    func deliver(alert: Alert, sample: Sample) {
        var body = alert.message
        if let groupID = alert.groupID,
           let known = KnowledgeBase.shared.match(groupID: groupID) {
            body += "\n\(known.title): \(known.explanation)"
        }
        let category: NotificationCategory
        if alert.ruleID == "memory_leak" {
            category = .leakAlert
        } else if alert.groupID != nil {
            category = .processAlert
        } else {
            category = .systemAlert
        }
        notifier.send(
            NotificationPayload(
                category: category,
                title: alert.title,
                body: body,
                userInfo: [
                    "rule": alert.ruleID,
                    "group": alert.groupID ?? "",
                ],
                identifier: "heatglance.alert.\(alert.id).\(Int(sample.date.timeIntervalSince1970))",
                logsAsEvent: false
            )
        )
    }

    func deliverTrends(_ findings: TrendsFindings, sample: Sample) {
        for leak in findings.leaks {
            guard trends.shouldNotify(key: "leak|\(leak.groupID)", now: sample.date, window: 86_400) else {
                continue
            }
            notifier.send(
                NotificationPayload(
                    category: .leakAlert,
                    title: "\(leak.displayName) keeps growing in memory",
                    body: "Memory grew by at least 1 GB over the last three hours and keeps rising. Relaunch the app to free it.",
                    userInfo: ["group": leak.groupID, "rule": "memory_leak"],
                    identifier: "heatglance.leak.\(leak.groupID).\(Int(sample.date.timeIntervalSince1970))"
                )
            )
        }
        for writes in findings.writeOffenders {
            let key = "writes|\(writes.displayName)"
            guard trends.shouldNotify(key: key, now: sample.date, window: 86_400) else {
                continue
            }
            notifier.send(
                NotificationPayload(
                    category: .systemAlert,
                    title: "\(writes.displayName) is writing a lot to disk",
                    body: "It wrote \(Int(Double(writes.dayBytes) / 1_073_741_824)) GB today. This wears the SSD and heats the Mac.",
                    identifier: "heatglance.writes.\(writes.displayName).\(Int(sample.date.timeIntervalSince1970))"
                )
            )
        }
        for anomaly in findings.anomalies {
            let key = "anomaly|\(anomaly.groupID)|\(anomaly.kind)"
            guard trends.shouldNotify(key: key, now: sample.date, window: 3600) else {
                continue
            }
            let title: String
            if anomaly.kind == .cpu {
                title = "\(anomaly.displayName) is using \(Int(anomaly.multiplier))× its usual CPU"
            } else {
                title = "\(anomaly.displayName) is using \(Int(anomaly.multiplier))× its usual memory"
            }
            notifier.send(
                NotificationPayload(
                    category: .processAlert,
                    title: title,
                    body: "Compared with what it usually does over the last week.",
                    userInfo: ["group": anomaly.groupID, "rule": "anomaly"],
                    identifier: "heatglance.anomaly.\(anomaly.groupID).\(Int(sample.date.timeIntervalSince1970))"
                )
            )
        }
    }

    func deliver(notice: GuardNotice) {
        switch notice {
        case .presentAdvisory:
            let now = Date()
            if let last = lastPresenceNoticeAt, now.timeIntervalSince(last) < ThermalGuardPolicy.presentAdvisoryInterval {
                return
            }
            lastPresenceNoticeAt = now
            notifier.send(
                NotificationPayload(
                    category: .processAlert,
                    title: "Your Mac is getting hot",
                    body: "Thermal protection waits while you are at the Mac. Use Sleep display to let it act.",
                    identifier: "heatglance.present.\(Int(now.timeIntervalSince1970))"
                )
            )
        case let .noCulprit(charging, battery):
            var body = "No app is causing the heat."
            if charging {
                if let battery {
                    body = "No app is causing the heat. Your Mac is charging and the battery is at \(Int(battery)) °C."
                } else {
                    body = "No app is causing the heat. Your Mac is charging."
                }
            }
            notifier.send(
                NotificationPayload(
                    category: .systemAlert,
                    title: "Heat without a culprit",
                    body: body,
                    identifier: "heatglance.noculprit.\(Int(Date().timeIntervalSince1970))"
                )
            )
        case let .suspended(groups):
            notifier.send(
                NotificationPayload(
                    category: .protectionAlert,
                    title: "Thermal protection paused \(groups.count) apps",
                    body: groups.map(\.displayName).joined(separator: ", "),
                    userInfo: ["groups": groups.map(\.groupID).joined(separator: ",")],
                    identifier: "heatglance.protection.\(Int(Date().timeIntervalSince1970))",
                    logsAsEvent: false
                )
            )
        case let .returned(groups):
            notifier.send(
                NotificationPayload(
                    category: .protectionReturn,
                    title: "Welcome back",
                    body: "HeatGlance paused \(groups.count) apps while you were away.",
                    identifier: "heatglance.return.\(Int(Date().timeIntervalSince1970))",
                    logsAsEvent: false
                )
            )
        }
    }

    func installObservers() {
        guard observers.isEmpty else {
            return
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: .heatGlanceTurnOffProtection, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else {
                    return
                }
                if self.settings.protection.isEnabled {
                    self.toggleProtection()
                }
            }
        })
        observers.append(center.addObserver(forName: .heatGlanceIgnoreRule, object: nil, queue: .main) { [weak self] notification in
            let rule = notification.userInfo?["rule"] as? String ?? ""
            Task { @MainActor in
                self?.ignore(ruleID: rule, label: rule)
            }
        })
        observers.append(center.addObserver(forName: .heatGlanceProcessAction, object: nil, queue: .main) { [weak self] notification in
            let groupID = notification.userInfo?["group"] as? String ?? ""
            let action = notification.userInfo?["action"] as? String ?? ""
            Task { @MainActor in
                guard let self, let group = self.latest?.groups.first(where: { $0.id == groupID }) else {
                    return
                }
                switch action {
                case NotificationAction.suspend.rawValue:
                    self.action(.suspend, on: group)
                case NotificationAction.quit.rawValue:
                    self.action(.quit, on: group)
                default:
                    break
                }
            }
        })
    }
}
