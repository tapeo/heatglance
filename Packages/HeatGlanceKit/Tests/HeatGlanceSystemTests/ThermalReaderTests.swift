import Testing

@testable import HeatGlanceSystem

#if canImport(AppKit)
@Suite("Thermal reader")
struct ThermalReaderTests {
    @Test("Every process info state maps to a thermal level")
    func mapping() {
        #expect(ThermalReader.thermalLevel(for: .nominal) == .nominal)
        #expect(ThermalReader.thermalLevel(for: .fair) == .fair)
        #expect(ThermalReader.thermalLevel(for: .serious) == .serious)
        #expect(ThermalReader.thermalLevel(for: .critical) == .critical)
    }
}
#endif
