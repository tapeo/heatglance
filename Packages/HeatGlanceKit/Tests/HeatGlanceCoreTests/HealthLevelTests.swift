import Testing

@testable import HeatGlanceCore

@Suite("Health levels")
struct HealthLevelTests {
    @Test("Ordering follows severity")
    func ordering() {
        #expect(HealthLevel.normal < HealthLevel.elevated)
        #expect(HealthLevel.elevated < HealthLevel.critical)
    }

    @Test("Worst of an empty list is normal")
    func worstOfEmpty() {
        #expect(HealthLevel.worst(of: []) == .normal)
    }

    @Test("Worst of a single level is that level")
    func worstOfSingle() {
        #expect(HealthLevel.worst(of: [.elevated]) == .elevated)
    }

    @Test("Worst picks the highest")
    func worstOfMany() {
        #expect(HealthLevel.worst(of: [.normal, .critical, .elevated]) == .critical)
        #expect(HealthLevel.worst(of: [.normal, .elevated]) == .elevated)
    }

    @Test("Every level has a title")
    func titles() {
        for level in HealthLevel.allCases {
            #expect(!level.title.isEmpty)
        }
    }
}

@Suite("Thermal and memory levels")
struct LevelMappingTests {
    @Test(
        "Thermal state maps to a health level",
        arguments: [
            (ThermalLevel.nominal, HealthLevel.normal),
            (ThermalLevel.fair, HealthLevel.normal),
            (ThermalLevel.serious, HealthLevel.elevated),
            (ThermalLevel.critical, HealthLevel.critical),
        ]
    )
    func thermalMapping(input: ThermalLevel, expected: HealthLevel) {
        #expect(input.healthLevel == expected)
    }

    @Test(
        "Memory pressure maps to a health level",
        arguments: [
            (MemoryPressureLevel.normal, HealthLevel.normal),
            (MemoryPressureLevel.warning, HealthLevel.elevated),
            (MemoryPressureLevel.critical, HealthLevel.critical),
        ]
    )
    func memoryMapping(input: MemoryPressureLevel, expected: HealthLevel) {
        #expect(input.healthLevel == expected)
    }
}
