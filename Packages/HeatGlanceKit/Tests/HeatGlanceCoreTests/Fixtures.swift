import Foundation
import Testing

@testable import HeatGlanceCore

enum Fixtures {
    static let baseDate = Date(timeIntervalSince1970: 1_700_000_000)

    static func process(
        pid: Int32 = 100,
        name: String = "Worker",
        cpu: Double = 0,
        footprint: UInt64 = 0,
        written: UInt64 = 0,
        path: String = "/usr/bin/worker"
    ) -> ProcessSnapshot {
        ProcessSnapshot(
            identity: ProcessIdentity(pid: pid, startTime: baseDate),
            parentPID: 1,
            userID: 501,
            name: name,
            executablePath: path,
            cpuPercent: cpu,
            footprintBytes: footprint,
            bytesWritten: written
        )
    }

    static func group(
        id: String = "com.example.app",
        name: String = "Example",
        cpu: Double = 0,
        footprint: UInt64 = 0,
        written: UInt64 = 0
    ) -> ProcessGroup {
        ProcessGroup(
            id: id,
            displayName: name,
            bundleIdentifier: id.contains("com.") ? id : nil,
            members: [process(cpu: cpu, footprint: footprint, written: written)]
        )
    }

    static func sample(
        date: Date = baseDate,
        thermal: ThermalLevel = .nominal,
        memoryPressure: MemoryPressureLevel = .normal,
        swapUsed: UInt64 = 0,
        physical: UInt64 = 16 * 1_073_741_824,
        systemCPU: Double = 5,
        diskAvailable: Int64 = 500_000_000_000,
        diskTotal: Int64 = 1_000_000_000_000,
        groups: [ProcessGroup] = []
    ) -> Sample {
        Sample(
            date: date,
            thermal: thermal,
            temperatureCelsius: nil,
            memoryPressure: memoryPressure,
            swapUsedBytes: swapUsed,
            physicalMemoryBytes: physical,
            systemCPUPercent: systemCPU,
            diskAvailableBytes: diskAvailable,
            diskTotalBytes: diskTotal,
            groups: groups
        )
    }
}
