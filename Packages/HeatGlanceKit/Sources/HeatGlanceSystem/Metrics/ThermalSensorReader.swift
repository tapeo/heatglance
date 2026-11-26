import Foundation

#if canImport(Darwin) && canImport(IOKit)
import IOKit

public enum ThermalSensorReader {
    public static let isAvailable: Bool = {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return false
        }
        defer { dlclose(handle) }
        return dlsym(handle, "IOHIDEventSystemClientCreateWithType") != nil
    }()

    public static func hottestDieTemperature() -> Double? {
        guard let handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW) else {
            return nil
        }
        defer { dlclose(handle) }

        typealias CreateClient = @convention(c) (CFAllocator?) -> OpaquePointer?
        typealias CopyServices = @convention(c) (OpaquePointer?) -> CFArray?
        typealias CreateEvent = @convention(c) (CFAllocator?, Int64, Int32, Int64) -> OpaquePointer?
        typealias CopyEvent = @convention(c) (OpaquePointer?, OpaquePointer?, Int32, Int64) -> OpaquePointer?
        typealias CopyProperty = @convention(c) (OpaquePointer?, CFString?) -> CFTypeRef?
        typealias GetDouble = @convention(c) (OpaquePointer?, Int32) -> Double

        guard let clientSymbol = dlsym(handle, "IOHIDEventSystemClientCreateWithType"),
              let servicesSymbol = dlsym(handle, "IOHIDEventSystemClientCopyServices"),
              let eventSymbol = dlsym(handle, "IOHIDEventCreate"),
              let copyEventSymbol = dlsym(handle, "IOHIDServiceClientCopyEvent"),
              let propertySymbol = dlsym(handle, "IOHIDServiceClientCopyProperty"),
              let floatSymbol = dlsym(handle, "IOHIDEventGetFloatValue")
        else {
            return nil
        }

        let create = unsafeBitCast(clientSymbol, to: CreateClient.self)
        let copyServices = unsafeBitCast(servicesSymbol, to: CopyServices.self)
        let createEvent = unsafeBitCast(eventSymbol, to: CreateEvent.self)
        let copyEvent = unsafeBitCast(copyEventSymbol, to: CopyEvent.self)
        let copyProperty = unsafeBitCast(propertySymbol, to: CopyProperty.self)
        let getFloat = unsafeBitCast(floatSymbol, to: GetDouble.self)

        let temperatureEventType: Int64 = 15
        let temperatureField: Int32 = 15 << 16
        let productKey = "Product" as CFString

        guard let client = create(nil),
              let services = copyServices(client) as? [OpaquePointer]
        else {
            return nil
        }

        var hottest = -Double.greatestFiniteMagnitude
        for service in services {
            let product = copyProperty(service, productKey).flatMap { $0 as? String } ?? ""
            guard product.contains("tdie") || product.contains("TDIE") else {
                continue
            }
            guard let event = createEvent(nil, temperatureEventType, 0, 0),
                  let reading = copyEvent(service, event, 0, 0)
            else {
                continue
            }
            let value = getFloat(reading, temperatureField)
            if value > hottest && value < 150 {
                hottest = value
            }
        }

        guard hottest > -Double.greatestFiniteMagnitude else {
            return nil
        }
        return hottest
    }
}
#endif
