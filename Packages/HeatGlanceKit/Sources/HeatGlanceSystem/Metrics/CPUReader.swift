import Foundation

#if canImport(Darwin)
import Darwin

public actor CPUReader {
    private var previousTicks: (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)?

    public init() {}

    public func read() -> Double {
        guard let current = readTicks() else {
            return 0
        }
        guard let previous = previousTicks else {
            previousTicks = current
            return 0
        }
        previousTicks = current

        let user = current.user &- previous.user
        let system = current.system &- previous.system
        let idle = current.idle &- previous.idle
        let nice = current.nice &- previous.nice
        let total = Double(user) + Double(system) + Double(idle) + Double(nice)
        guard total > 0 else {
            return 0
        }
        let busy = Double(user) + Double(system) + Double(nice)
        return min(busy / total * 100, 100)
    }

    private func readTicks() -> (user: UInt32, system: UInt32, idle: UInt32, nice: UInt32)? {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfo,
            &cpuInfoCount
        )
        guard result == KERN_SUCCESS, let cpuInfo else {
            return nil
        }
        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), size)
        }

        var user: UInt32 = 0
        var system: UInt32 = 0
        var idle: UInt32 = 0
        var nice: UInt32 = 0
        for index in 0..<Int(cpuCount) {
            let base = index * Int(CPU_STATE_MAX)
            user &+= UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_USER)])
            system &+= UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_SYSTEM)])
            idle &+= UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_IDLE)])
            nice &+= UInt32(bitPattern: cpuInfo[base + Int(CPU_STATE_NICE)])
        }
        return (user, system, idle, nice)
    }
}
#endif
