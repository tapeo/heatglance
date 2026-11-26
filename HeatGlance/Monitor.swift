import Foundation

import HeatGlanceCore
import HeatGlanceSystem

@MainActor
@Observable
final class Monitor {
    static let shared = Monitor()

    var latest: Sample?
    var ruleState = RuleState()
    var guardState = GuardState()
    var presence: Presence = .present
    var suspendedGroups: [SuspendedGroup] = []
    var ignoreList = IgnoreList()
    var overall: HealthLevel = .normal
    var isSampling = false
    var thermalOverride: ThermalLevel?
    var history = HistoryStore()
    var lastKnownItem: KnownItem?

    let settings = AppSettingsStore()
    let registry = SuspendedProcessRegistry()
    let notifier = Notifier()

    private let sampler = Sampler()
    private let presenceMonitor = PresenceMonitor()
    private let engine = RuleEngine()
    private let guardPolicy = ThermalGuardPolicy()
    private var samplerTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    private var lastPresenceNoticeAt: Date?
    private var lastHistorySaveAt: Date?
    private var observers: [NSObjectProtocol] = []

    private init() {
        loadIgnoreList()
        loadHistory()
        settings.onChange = { [weak self] in
            self?.applySettings()
        }
        installObservers()
    }

    func start() {
        guard samplerTask == nil else {
            return
        }
        isSampling = true
        samplerTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await sample in await sampler.start() {
                await self.handle(sample: sample)
            }
        }
        presenceTask = Task { [weak self] in
            guard let self else {
                return
            }
            for await signals in await presenceMonitor.start() {
                await self.handle(signals: signals)
            }
        }
        Task {
            await registry.recoverAll()
        }
    }

    func stop() {
        samplerTask?.cancel()
        presenceTask?.cancel()
        samplerTask = nil
        presenceTask = nil
    }

    func shutdown() {
        stop()
        saveHistory()
        Task {
            await registry.recoverAll()
        }
    }

    func setThermalOverride(_ level: ThermalLevel?) {
        thermalOverride = level
        Task {
            await sampler.setThermalOverride(level)
        }
    }

    func action(_ action: ProcessActionKind, on group: ProcessGroup) {
        Task {
            for identity in group.identities {
                await perform(action, identity: identity)
            }
        }
    }

    func resume(groupID: String) {
        guard let group = latest?.groups.first(where: { $0.id == groupID }) else {
            guardState.suspended.removeAll { $0.groupID == groupID }
            suspendedGroups = guardState.suspended
            return
        }
        Task {
            for identity in group.identities {
                _ = ProcessActions.resume(identity)
                await registry.remove(identity)
            }
            guardState.suspended.removeAll { $0.groupID == groupID }
            suspendedGroups = guardState.suspended
        }
    }

    func resumeAllSuspended() {
        Task {
            await registry.resumeAll(origin: nil)
            guardState.suspended.removeAll()
            suspendedGroups = []
        }
    }

    func toggleProtection() {
        settings.protection.isEnabled.toggle()
        if !settings.protection.isEnabled {
            resumeAllSuspended()
        }
    }

    func pauseProtection(until date: Date) {
        resumeAllSuspended()
        settings.protection.pausedUntil = date
    }

    func resumeProtectionNow() {
        settings.protection.pausedUntil = nil
    }

    func sleepDisplay() {
        _ = DisplaySleeper.sleepDisplay()
    }

    func ignore(ruleID: String, label: String) {
        let entry = IgnoreEntry(
            kind: .rule,
            value: ruleID,
            label: label,
            expiresAt: Date().addingTimeInterval(3600)
        )
        ignoreList.add(entry)
        persistIgnoreList()
    }

    func ignoreGroup(_ group: ProcessGroup) {
        let entry = IgnoreEntry(
            kind: .group,
            value: group.id,
            label: group.displayName,
            expiresAt: Date().addingTimeInterval(3600)
        )
        ignoreList.add(entry)
        persistIgnoreList()
    }

    func removeIgnore(id: String) {
        ignoreList.remove(id: id)
        persistIgnoreList()
    }

    func knownItem(for group: ProcessGroup) -> KnownItem? {
        KnowledgeBase.shared.match(
            groupID: group.id,
            processName: group.members.first?.name,
            executablePath: group.members.first?.executablePath
        )
    }

    private func handle(sample: Sample) async {
        latest = sample
        let result = engine.evaluate(
            sample: sample,
            settings: settings.settings,
            state: ruleState,
            now: sample.date,
            ignoredKeys: ignoreList.activeKeys(at: sample.date)
        )
        ruleState = result.state
        overall = HealthLevel.worst(of: engine.activeLevels(state: ruleState))
        history.record(sample)
        if let last = lastHistorySaveAt {
            if sample.date.timeIntervalSince(last) > 600 {
                saveHistory()
                lastHistorySaveAt = sample.date
            }
        } else {
            lastHistorySaveAt = sample.date
        }
        for alert in result.alerts {
            deliver(alert: alert, sample: sample)
        }
        evaluateGuard(sample: sample)
    }

    private func handle(signals: PresenceSignals) async {
        let previous = presence
        presence = PresencePolicy().evaluate(signals, settings: settings.presence)
        if previous == .absent && presence != .absent && !suspendedGroups.isEmpty {
            let groups = suspendedGroups
            notifier.send(
                NotificationPayload(
                    category: .protectionReturn,
                    title: "Welcome back",
                    body: "While you were away, HeatGlance paused \(groups.count) apps: \(groups.map(\.displayName).joined(separator: ", ")).",
                    userInfo: ["groups": groups.map(\.groupID).joined(separator: ",")],
                    identifier: "heatglance.return.\(Int(Date().timeIntervalSince1970))"
                )
            )
        }
    }

    private func evaluateGuard(sample: Sample) {
        let power = PowerSourceReader.read()
        let input = GuardInput(
            thermal: sample.thermal,
            presence: presence,
            groups: sample.groups,
            power: PowerStateSnapshot(
                isOnACPower: power.isOnACPower,
                isCharging: power.isCharging,
                batteryTemperatureCelsius: power.batteryTemperatureCelsius
            ),
            settings: settings.protection,
            now: sample.date
        )
        let result = guardPolicy.decide(input: input, state: guardState)
        guardState = result.state
        suspendedGroups = guardState.suspended
        for action in result.actions {
            switch action {
            case let .suspend(groupIDs):
                for groupID in groupIDs {
                    suspendGroup(groupID: groupID)
                }
            case let .resume(groupIDs):
                for groupID in groupIDs {
                    resume(groupID: groupID)
                }
            case let .notice(notice):
                deliver(notice: notice)
            }
        }
    }

    private func suspendGroup(groupID: String) {
        guard let group = latest?.groups.first(where: { $0.id == groupID }) else {
            return
        }
        Task {
            for identity in group.identities {
                if ProcessActions.suspend(identity) == .done {
                    await registry.record(
                        SuspendedProcessEntry(
                            identity: identity,
                            origin: .protection,
                            reason: "Protection paused \(group.displayName)",
                            suspendedAt: Date()
                        )
                    )
                }
            }
        }
    }

    private func perform(_ kind: ProcessActionKind, identity: ProcessIdentity) async {
        switch kind {
        case .suspend:
            if ProcessActions.suspend(identity) == .done {
                await registry.record(
                    SuspendedProcessEntry(
                        identity: identity,
                        origin: .manual,
                        reason: "Suspended from the menu",
                        suspendedAt: Date()
                    )
                )
            }
        case .resume:
            _ = ProcessActions.resume(identity)
            await registry.remove(identity)
        case .quit:
            _ = ProcessActions.quit(identity)
        case .forceQuit:
            _ = ProcessActions.forceQuit(identity)
        }
    }

    private func deliver(alert: Alert, sample: Sample) {
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
                identifier: "heatglance.alert.\(alert.id).\(Int(sample.date.timeIntervalSince1970))"
            )
        )
    }

    private func deliver(notice: GuardNotice) {
        switch notice {
        case .presentAdvisory:
            let now = Date()
            if let last = lastPresenceNoticeAt, now.timeIntervalSince(last) < 900 {
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
                    identifier: "heatglance.protection.\(Int(Date().timeIntervalSince1970))"
                )
            )
        case let .returned(groups):
            notifier.send(
                NotificationPayload(
                    category: .protectionReturn,
                    title: "Welcome back",
                    body: "HeatGlance paused \(groups.count) apps while you were away.",
                    identifier: "heatglance.return.\(Int(Date().timeIntervalSince1970))"
                )
            )
        }
    }

    private func installObservers() {
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

    private func applySettings() {
        Task {
            await sampler.setThermalOverride(thermalOverride)
        }
    }

    private func loadIgnoreList() {
        if let stored = try? JSONFileStore.load(IgnoreList.self, from: SupportDirectory.url(file: "ignored.json")) {
            ignoreList = stored
        }
    }

    private func persistIgnoreList() {
        try? JSONFileStore.save(ignoreList, to: SupportDirectory.url(file: "ignored.json"))
    }

    private func loadHistory() {
        if let stored = try? JSONFileStore.load(HistoryStore.self, from: SupportDirectory.url(file: "history.json")) {
            history = stored
        }
    }

    private func saveHistory() {
        try? JSONFileStore.save(history, to: SupportDirectory.url(file: "history.json"))
    }
}

enum ProcessActionKind {
    case suspend
    case resume
    case quit
    case forceQuit
}
