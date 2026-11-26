import Foundation

public struct ExplanationSection: Sendable, Equatable, Identifiable {
    public let title: String
    public let paragraphs: [String]

    public init(title: String, paragraphs: [String]) {
        self.title = title
        self.paragraphs = paragraphs
    }

    public var id: String {
        title
    }
}

public enum ProtectionExplanation {
    public static func sections(protection: ProtectionSettings, presence: PresenceSettings) -> [ExplanationSection] {
        [
            whenItActs(protection: protection, presence: presence),
            whatItPauses(protection: protection),
            whenAppsResume(protection: protection),
            neverPause(protection: protection),
            offAndPause(),
        ]
    }

    public static func duration(_ seconds: Double) -> String {
        let whole = Int(seconds.rounded())
        if whole == 3600 {
            return "1 hour"
        }
        if whole > 3600 && whole % 3600 == 0 {
            return "\(whole / 3600) hours"
        }
        if whole == 60 {
            return "1 minute"
        }
        if whole > 60 && whole % 60 == 0 {
            return "\(whole / 60) minutes"
        }
        if whole == 1 {
            return "1 second"
        }
        return "\(whole) seconds"
    }

    private static func whenItActs(protection: ProtectionSettings, presence: PresenceSettings) -> ExplanationSection {
        let trigger = protection.triggerLevel.title.lowercased()
        var paragraphs: [String] = []
        paragraphs.append(
            "HeatGlance acts when macOS reports a thermal state of \(trigger) or higher for at least \(duration(protection.sustainSeconds)), and only while you are away."
        )
        paragraphs.append(
            "You count as away when the screen is locked, the display is asleep, the screen saver is running, you switched to another user, or you have not used the keyboard or mouse for \(duration(presence.idleThresholdSeconds))."
        )
        if let signals = passiveSignals(presence) {
            paragraphs.append(
                "While \(signals) is in use, you still count as present until you have been idle for \(duration(presence.passiveCapSeconds))."
            )
        }
        paragraphs.append(
            "While you are at the Mac it never pauses anything. It sends a notification instead, at most every \(duration(ThermalGuardPolicy.presentAdvisoryInterval)). Sleep display in the menu lets it act."
        )
        return ExplanationSection(title: "When it acts", paragraphs: paragraphs)
    }

    private static func passiveSignals(_ presence: PresenceSettings) -> String? {
        var signals: [String] = []
        if presence.useDisplaySleepAssertion {
            signals.append("video or a presentation")
        }
        if presence.useMicrophone {
            signals.append("the microphone")
        }
        if presence.useCamera {
            signals.append("the camera")
        }
        guard !signals.isEmpty else {
            return nil
        }
        if signals.count == 1 {
            return signals[0]
        }
        let head = signals.dropLast().joined(separator: ", ")
        return head + " or " + signals[signals.count - 1]
    }

    private static func whatItPauses(protection: ProtectionSettings) -> ExplanationSection {
        let paragraphs = [
            "It pauses apps that use at least \(Int(protection.culpritCPUThreshold))% CPU, the heaviest first, up to \(protection.maxGroupsPerRound) per round.",
            "If the Mac is still hot \(duration(protection.secondRoundAfterSeconds)) later, it starts another round. No new round starts once \(protection.maxGroupsTotal) apps are paused.",
            "Only processes that belong to an app with a bundle identifier are paused. Command line tools and daemons without one, HeatGlance itself and the apps in the never pause list are left alone.",
            "Pausing sends SIGSTOP. The app stays open with its windows and data, and uses no CPU until it resumes.",
            "If no app is above the threshold, nothing is paused and a notification says the heat has no culprit, and whether the Mac is charging.",
        ]
        return ExplanationSection(title: "What it pauses", paragraphs: paragraphs)
    }

    private static func whenAppsResume(protection: ProtectionSettings) -> ExplanationSection {
        let trigger = protection.triggerLevel.title.lowercased()
        let paragraphs = [
            "Once the thermal state stays below \(trigger) for \(duration(protection.resumeAfterCoolSeconds)), it resumes one app every \(duration(protection.resumeIntervalSeconds)), starting with the one that used the least CPU.",
            "After each resume it waits \(duration(protection.cooldownAfterResumeSeconds)) before it pauses anything again.",
            "When you come back, a notification lists the paused apps. Resume and Resume all in the menu bring them back at any time.",
            "When HeatGlance quits it resumes every app it paused. After a crash it does so at the next launch.",
        ]
        return ExplanationSection(title: "When apps resume", paragraphs: paragraphs)
    }

    private static func neverPause(protection: ProtectionSettings) -> ExplanationSection {
        if protection.neverPause.isEmpty {
            let paragraphs = [
                "No apps are on the list. Add bundle identifiers in Settings, Protection, and HeatGlance never pauses those apps.",
            ]
            return ExplanationSection(title: "Never pause", paragraphs: paragraphs)
        }
        let paragraphs = [
            "These apps are never paused: \(protection.neverPause.joined(separator: ", ")).",
            "Edit the list in Settings, Protection.",
        ]
        return ExplanationSection(title: "Never pause", paragraphs: paragraphs)
    }

    private static func offAndPause() -> ExplanationSection {
        let paragraphs = [
            "Turning protection off, or pausing it from the menu for 1 hour or until tomorrow, resumes every paused app right away.",
            "While paused it does nothing until the time runs out or you choose Resume now.",
        ]
        return ExplanationSection(title: "Turning it off or pausing it", paragraphs: paragraphs)
    }
}
