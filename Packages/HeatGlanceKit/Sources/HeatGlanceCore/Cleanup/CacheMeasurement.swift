import Foundation

public enum CacheMeasurement: Sendable, Equatable {
    case measuring
    case size(bytes: Int64, isUpperBound: Bool)
    case empty
    case notInstalled
    case notRunning
    case unknown

    public static func of(bytes: Int64?, source: CacheSizeSource) -> CacheMeasurement {
        guard let bytes, bytes > 0 else {
            return .empty
        }
        return .size(bytes: bytes, isUpperBound: source.isUpperBound)
    }

    public var canClean: Bool {
        switch self {
        case .size, .unknown:
            return true
        case .measuring, .empty, .notInstalled, .notRunning:
            return false
        }
    }
}

public enum SimulatorList {
    private struct Listing: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let isAvailable: Bool?
        let availability: String?
        let dataPath: String?

        var isUnavailable: Bool {
            if let isAvailable {
                return !isAvailable
            }
            if let availability {
                return availability.contains("unavailable")
            }
            return false
        }
    }

    public static func unavailableDeviceFolders(json: Data, devicesRoot: String) -> [String]? {
        guard let listing = try? JSONDecoder().decode(Listing.self, from: json) else {
            return nil
        }
        var folders: Set<String> = []
        for device in listing.devices.values.joined() where device.isUnavailable {
            folders.insert(folder(for: device, devicesRoot: devicesRoot))
        }
        return folders.sorted()
    }

    private static func folder(for device: Device, devicesRoot: String) -> String {
        if let dataPath = device.dataPath {
            return URL(fileURLWithPath: dataPath).deletingLastPathComponent().path
        }
        return devicesRoot + "/" + device.udid
    }
}

public enum DockerDiskUsage {
    private static let multipliers: [String: Double] = [
        "B": 1,
        "KB": 1_000,
        "MB": 1_000_000,
        "GB": 1_000_000_000,
        "TB": 1_000_000_000_000,
        "PB": 1_000_000_000_000_000,
    ]

    public static func reclaimableImageBytes(output: String) -> Int64? {
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            if parts[0].trimmingCharacters(in: .whitespaces) == "Images" {
                return bytes(fromHumanSize: String(parts[1]))
            }
        }
        return nil
    }

    public static func bytes(fromHumanSize text: String) -> Int64? {
        let sizePart = text.split(separator: "(").first.map(String.init) ?? ""
        let token = sizePart.trimmingCharacters(in: .whitespaces)
        let number = String(token.prefix { $0.isNumber || $0 == "." })
        let unit = token.dropFirst(number.count).trimmingCharacters(in: .whitespaces).uppercased()
        guard let value = Double(number), let multiplier = multipliers[unit] else {
            return nil
        }
        return Int64(value * multiplier)
    }
}
