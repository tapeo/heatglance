import Foundation

import HeatGlanceCore
import HeatGlanceSystem

@MainActor
@Observable
final class Monitor {
    static let shared = Monitor()

    var latest: Sample?
    var ruleState = RuleState()
    var activeRules: [ActiveRule] = []
    var guardState = GuardState()
    var presence: Presence = .present
    var suspendedGroups: [SuspendedGroup] = []
    var ignoreList = IgnoreList()
    var overall: HealthLevel = .normal
    var isSampling = false
    var thermalOverride: ThermalLevel?
    var history = HistoryStore()
    var eventLog = HistoryEventLog()
    var lastKnownItem: KnownItem?
    var trends = TrendsEngine.fresh(now: Date())
    var leftovers: [OrphanCandidate] = []
    var ignoredOrphans: [String] = []

    let settings: AppSettingsStore
    let registry = SuspendedProcessRegistry()
    let notifier: Notifier
    private let storage: StorageWatcher

    private let sampler = Sampler()
    private let presenceMonitor = PresenceMonitor()
    private let engine = RuleEngine()
    let guardPolicy = ThermalGuardPolicy()
    private var samplerTask: Task<Void, Never>?
    private var presenceTask: Task<Void, Never>?
    var lastPresenceNoticeAt: Date?
    private var lastHistorySaveAt: Date?
    private var lastOrphanScan = Date.distantPast
    private var lastProtectionMode: ProtectionMode?
    var snapshots: [TimeMachineSnapshots.Snapshot] = []
    var observers: [NSObjectProtocol] = []

    private init() {
        let settings = AppSettingsStore()
        let notifier = Notifier()
        self.settings = settings
        self.notifier = notifier
        self.storage = StorageWatcher(notifier: notifier, settings: settings)
        loadIgnoreList()
        loadHistory()
        notifier.onSend = { [weak self] payload in
            guard payload.logsAsEvent else {
                return
            }
            Task { @MainActor in
                self?.record([
                    HistoryEvent(kind: .notification, title: payload.title, detail: payload.body)
                ])
            }
        }
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
            await sampler.setFastSampling(settings.sampleFast)
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
        saveTrends()
        saveEvents()
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
        let descriptor = eventDescriptor(for: action)
        record([
            HistoryEvent(
                kind: descriptor.kind,
                title: descriptor.title,
                appName: group.displayName,
                value: HistoryEventValue.group(group)
            )
        ])
        Task {
            for identity in group.identities {
                await perform(action, identity: identity)
            }
        }
    }

    func resume(groupID: String) {
        let name = guardState.suspended.first { $0.groupID == groupID }?.displayName
        record([HistoryEvent(kind: .manualResume, title: "Resumed by you", appName: name)])
        resumeGroup(groupID: groupID)
    }

    func resumeAllSuspended() {
        let paused = guardState.suspended
        if !paused.isEmpty {
            record([
                HistoryEvent(
                    kind: .manualResume,
                    title: "Resumed all paused apps",
                    appName: paused.map(\.displayName).joined(separator: ", ")
                )
            ])
        }
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

    func ignoreOrphan(_ groupID: String) {
        if !ignoredOrphans.contains(groupID) {
            ignoredOrphans.append(groupID)
        }
        leftovers.removeAll { $0.groupID == groupID }
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
        let previousRules = activeRules
        let result = engine.evaluate(
            sample: sample,
            settings: settings.settings,
            state: ruleState,
            now: sample.date,
            ignoredKeys: ignoreList.activeKeys(at: sample.date)
        )
        ruleState = result.state
        activeRules = engine.activeRules(state: ruleState, now: sample.date)
        overall = HealthLevel.worst(of: activeRules.map(\.level))
        record(
            eventLog.alertEvents(
                previous: previousRules,
                current: activeRules,
                sample: sample,
                notifiedKeys: Set(result.alerts.map(\.activeRuleID))
            )
        )
        let findings = trends.update(sample: sample, settings: settings.settings)
        deliverTrends(findings, sample: sample)
        if leftovers.isEmpty || sample.date.timeIntervalSince(lastOrphanScan) > 300 {
            lastOrphanScan = sample.date
            leftovers = OrphanFinder.candidates(groups: sample.groups)
                .filter { !ignoredOrphans.contains($0.groupID) }
        }
        storage.handle(now: sample.date)
        if let last = lastHistorySaveAt {
            if sample.date.timeIntervalSince(last) > 600 {
                saveHistory()
                saveTrends()
                lastHistorySaveAt = sample.date
            }
        } else {
            lastHistorySaveAt = sample.date
        }
        evaluateGuard(sample: sample)
        checkProtectionMode(now: sample.date)
        history.record(sample, isAway: presence.isAway, pausedApps: guardState.suspended.count)
        for alert in result.alerts {
            deliver(alert: alert, sample: sample)
        }
    }

    private func handle(signals: PresenceSignals) async {
        let previous = presence
        presence = PresencePolicy().evaluate(signals, settings: settings.presence)
        let welcomesBack = previous == .absent && presence != .absent && !suspendedGroups.isEmpty
        if let event = eventLog.presenceEvent(previous: previous, current: presence, at: Date(), notified: welcomesBack) {
            record([event])
        }
        guard welcomesBack else {
            return
        }
        let groups = suspendedGroups
        notifier.send(
            NotificationPayload(
                category: .protectionReturn,
                title: "Welcome back",
                body: "While you were away, HeatGlance paused \(groups.count) apps: \(groups.map(\.displayName).joined(separator: ", ")).",
                userInfo: ["groups": groups.map(\.groupID).joined(separator: ",")],
                identifier: "heatglance.return.\(Int(Date().timeIntervalSince1970))",
                logsAsEvent: false
            )
        )
    }

    func loadSnapshots() {
        snapshots = TimeMachineSnapshots.list()
    }

    func deleteSnapshot(_ snapshot: TimeMachineSnapshots.Snapshot) {
        _ = TimeMachineSnapshots.delete(date: snapshot.date)
        loadSnapshots()
    }

    private func applySettings() {
        Task {
            await sampler.setThermalOverride(thermalOverride)
            await sampler.setFastSampling(settings.sampleFast)
        }
        _ = LoginItem.setEnabled(settings.launchAtLogin)
        notifier.scheduleWeeklySummary(enabled: settings.weeklySummaryEnabled)
        checkProtectionMode(now: Date())
    }

    private func checkProtectionMode(now: Date) {
        let current = settings.protection.mode(at: now)
        if let previous = lastProtectionMode {
            if let event = eventLog.protectionEvent(previous: previous, current: current, at: now) {
                record([event])
            }
        }
        lastProtectionMode = current
    }

    func record(_ events: [HistoryEvent]) {
        guard !events.isEmpty else {
            return
        }
        eventLog.append(events)
        saveEvents()
    }

    private func eventDescriptor(for action: ProcessActionKind) -> (kind: HistoryEventKind, title: String) {
        switch action {
        case .suspend:
            return (.manualSuspend, "Suspended by you")
        case .resume:
            return (.manualResume, "Resumed by you")
        case .quit:
            return (.manualQuit, "Quit by you")
        case .forceQuit:
            return (.manualForceQuit, "Force quit by you")
        }
    }
}

enum ProcessActionKind {
    case suspend
    case resume
    case quit
    case forceQuit
}
