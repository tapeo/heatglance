import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("Cache measurement")
struct CacheMeasurementTests {
    @Test("Human sizes from docker become bytes")
    func humanSizes() {
        #expect(DockerDiskUsage.bytes(fromHumanSize: "16.43 MB") == 16_430_000)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "11.63MB (70%)") == 11_630_000)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "0B") == 0)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "1.2GB") == 1_200_000_000)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "212 B (100%)") == 212)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "5kB") == 5_000)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "abc") == nil)
        #expect(DockerDiskUsage.bytes(fromHumanSize: "") == nil)
    }

    @Test("Reclaimable image size comes from the Images line")
    func reclaimableImages() {
        let output = "Images|11.63MB (70%)\nContainers|212B (100%)\nLocal Volumes|0B (0%)\nBuild Cache|1.2GB (100%)"
        #expect(DockerDiskUsage.reclaimableImageBytes(output: output) == 11_630_000)
        #expect(DockerDiskUsage.reclaimableImageBytes(output: "Containers|212B (100%)") == nil)
    }

    @Test("Unavailable simulators map to their folders")
    func unavailableSimulators() {
        let json = "{\"devices\":{\"com.apple.CoreSimulator.SimRuntime.iOS-17-0\":[" +
            "{\"udid\":\"AAA\",\"isAvailable\":false,\"dataPath\":\"/root/Devices/AAA/data\"}," +
            "{\"udid\":\"CCC\",\"isAvailable\":true}," +
            "{\"udid\":\"BBB\",\"availability\":\"(unavailable, runtime profile not found)\"}]}}"
        let folders = SimulatorList.unavailableDeviceFolders(json: Data(json.utf8), devicesRoot: "/root/Devices")
        #expect(folders == ["/root/Devices/AAA", "/root/Devices/BBB"])
        #expect(SimulatorList.unavailableDeviceFolders(json: Data("nope".utf8), devicesRoot: "/root/Devices") == nil)
    }

    @Test("A measurement reflects the source limit")
    func measurementOf() {
        #expect(CacheMeasurement.of(bytes: nil, source: .npmCache) == .empty)
        #expect(CacheMeasurement.of(bytes: 0, source: .npmCache) == .empty)
        #expect(CacheMeasurement.of(bytes: 5, source: .pnpmStore) == .size(bytes: 5, isUpperBound: true))
        #expect(CacheMeasurement.of(bytes: 5, source: .npmCache) == .size(bytes: 5, isUpperBound: false))
    }

    @Test("Only measured or unknown entries can be cleaned")
    func canClean() {
        #expect(!CacheMeasurement.empty.canClean)
        #expect(!CacheMeasurement.notInstalled.canClean)
        #expect(!CacheMeasurement.notRunning.canClean)
        #expect(!CacheMeasurement.measuring.canClean)
        #expect(CacheMeasurement.size(bytes: 1, isUpperBound: false).canClean)
        #expect(CacheMeasurement.unknown.canClean)
    }

    @Test("The catalog measures every entry and prunes Docker without prompting")
    func catalog() {
        let items = CacheCatalog().items
        let docker = items.first { $0.id == "docker" }
        #expect(docker?.method == CacheItem.Method.command(executable: "docker", arguments: ["image", "prune", "-f"]))
        for item in items {
            let shouldBeUpperBound = item.id == "pnpm" || item.id == "docker"
            #expect(item.size.isUpperBound == shouldBeUpperBound)
        }
    }
}
