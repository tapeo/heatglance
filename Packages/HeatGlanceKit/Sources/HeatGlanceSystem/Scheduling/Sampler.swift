import Foundation

import HeatGlanceCore

#if canImport(Darwin)
public actor Sampler {
    private let cpuReader = CPUReader()
    private let processReader = ProcessReader()
    private var thermal: ThermalLevel = ThermalReader.currentLevel()
    private var temperature: Double?

    public init() {}

    public func start() -> AsyncStream<Sample> {
        let stream = AsyncStream<Sample> { continuation in
            let task = Task {
                var thermalStreamTask: Task<Void, Never>?
                if #available(macOS 14.0, *) {
                    thermalStreamTask = Task {
                        for await level in ThermalStateStream.make() {
                            await self.setThermal(level)
                        }
                    }
                }
                defer { thermalStreamTask?.cancel() }
                while !Task.isCancelled {
                    let sample = await self.snapshot()
                    continuation.yield(sample)
                    let power = PowerSourceReader.read()
                    let seconds = power.isOnACPower ? 5.0 : 10.0
                    try? await Task.sleep(for: .seconds(seconds))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
        return stream
    }

    private func setThermal(_ level: ThermalLevel) {
        thermal = level
    }

    public func setThermalOverride(_ level: ThermalLevel?) {
        if let level {
            thermal = level
        } else {
            thermal = ThermalReader.currentLevel()
        }
    }

    private func snapshot() async -> Sample {
        let cpu = await cpuReader.read()
        let now = Date()
        let groups = await processReader.readGroups(now: now)
        let disk = DiskReader.state()
        if temperature == nil {
            temperature = ThermalSensorReader.hottestDieTemperature()
        }
        return Sample(
            date: now,
            thermal: thermal,
            temperatureCelsius: temperature,
            memoryPressure: MemoryReader.pressureLevel(),
            swapUsedBytes: MemoryReader.swapUsedBytes(),
            physicalMemoryBytes: MemoryReader.physicalMemoryBytes(),
            systemCPUPercent: cpu,
            diskAvailableBytes: disk.availableBytes,
            diskTotalBytes: disk.totalBytes,
            groups: groups
        )
    }
}
#endif
