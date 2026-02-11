import Foundation
import SwiftUI

// MARK: - Device Type (determines icon set)

enum DeviceType: String, Codable, CaseIterable, Identifiable {
    case garage = "garage"
    case gate = "gate"
    case barrier = "barrier"
    case shutter = "shutter"
    case door = "door"
    case other = "other"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .garage:  return "Garage Door"
        case .gate:    return "Gate"
        case .barrier: return "Barrier"
        case .shutter: return "Shutter"
        case .door:    return "Door"
        case .other:   return "Other"
        }
    }
    
    /// Icon when the device is CLOSED
    var closedIcon: String {
        switch self {
        case .garage:  return "door.garage.closed"
        case .gate:    return "door.french.closed"
        case .barrier: return "xmark.rectangle.fill"
        case .shutter: return "blinds.horizontal.closed"
        case .door:    return "door.left.hand.closed"
        case .other:   return "lock.fill"
        }
    }
    
    /// Icon when the device is OPEN
    var openIcon: String {
        switch self {
        case .garage:  return "door.garage.open"
        case .gate:    return "door.french.open"
        case .barrier: return "checkmark.rectangle.fill"
        case .shutter: return "blinds.horizontal.open"
        case .door:    return "door.left.hand.open"
        case .other:   return "lock.open.fill"
        }
    }
    
    /// Icon when status is unknown
    var unknownIcon: String {
        closedIcon   // Default to closed appearance
    }
    
    /// Default accent color for this type
    var defaultColor: DeviceColor {
        switch self {
        case .garage:  return .blue
        case .gate:    return .orange
        case .barrier: return .purple
        case .shutter: return .teal
        case .door:    return .indigo
        case .other:   return .gray
        }
    }
}

// MARK: - Device Color (Codable-friendly wrapper)

enum DeviceColor: String, Codable, CaseIterable, Identifiable {
    case blue, orange, green, red, purple, teal, indigo, pink, yellow, gray, cyan, mint
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .blue:   return .blue
        case .orange: return .orange
        case .green:  return .green
        case .red:    return .red
        case .purple: return .purple
        case .teal:   return .teal
        case .indigo: return .indigo
        case .pink:   return .pink
        case .yellow: return .yellow
        case .gray:   return .gray
        case .cyan:   return .cyan
        case .mint:   return .mint
        }
    }
}

// MARK: - Device Configuration

struct DeviceConfig: Codable, Identifiable, Hashable {
    var id: UUID
    var name: String
    var deviceType: DeviceType
    var ipAddress: String
    var apiSecretKey: String
    var apiAuthKey: String
    var accentColor: DeviceColor
    var sortOrder: Int
    
    /// Returns the appropriate icon for the given gate status
    func icon(for status: RemootioClient.GateStatus) -> String {
        switch status {
        case .open:     return deviceType.openIcon
        case .closed:   return deviceType.closedIcon
        case .noSensor, .unknown: return deviceType.unknownIcon
        }
    }
    
    var isValid: Bool {
        !name.isEmpty && !ipAddress.isEmpty && apiSecretKey.count == 64 && apiAuthKey.count == 64
    }
    
    static func newDevice(sortOrder: Int) -> DeviceConfig {
        DeviceConfig(
            id: UUID(),
            name: "",
            deviceType: .garage,
            ipAddress: "",
            apiSecretKey: "",
            apiAuthKey: "",
            accentColor: DeviceType.garage.defaultColor,
            sortOrder: sortOrder
        )
    }
}

// MARK: - Settings Storage (dynamic device list)

class SettingsStore: ObservableObject {
    
    static let shared = SettingsStore()
    
    private let defaults: UserDefaults
    private let storageKey = "remootio_devices_v2"
    
    @Published var devices: [DeviceConfig] = [] {
        didSet { save() }
    }
    
    var configuredDevices: [DeviceConfig] {
        devices.filter { $0.isValid }.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    var isConfigured: Bool {
        !configuredDevices.isEmpty
    }
    
    init() {
        if let groupDefaults = UserDefaults(suiteName: "group.com.remootiogate.shared") {
            self.defaults = groupDefaults
        } else {
            self.defaults = UserDefaults.standard
        }
        loadDevices()
        
        // Migration from v0.1
        if devices.isEmpty {
            migrateFromV1()
        }
    }
    
    // MARK: - CRUD
    
    @discardableResult
    func addDevice() -> DeviceConfig {
        let device = DeviceConfig.newDevice(sortOrder: devices.count)
        devices.append(device)
        return device
    }
    
    func updateDevice(_ device: DeviceConfig) {
        if let idx = devices.firstIndex(where: { $0.id == device.id }) {
            devices[idx] = device
        }
    }
    
    func removeDevice(id: UUID) {
        devices.removeAll { $0.id == id }
        for i in devices.indices {
            devices[i].sortOrder = i
        }
    }
    
    func moveDevice(from source: IndexSet, to destination: Int) {
        devices.move(fromOffsets: source, toOffset: destination)
        for i in devices.indices {
            devices[i].sortOrder = i
        }
    }
    
    // MARK: - Persistence
    
    private func save() {
        if let data = try? JSONEncoder().encode(devices) {
            defaults.set(data, forKey: storageKey)
            defaults.synchronize()
        }
    }
    
    private func loadDevices() {
        if let data = defaults.data(forKey: storageKey),
           let loaded = try? JSONDecoder().decode([DeviceConfig].self, from: data) {
            self.devices = loaded
        }
    }
    
    // MARK: - V1 Migration
    
    private func migrateFromV1() {
        var migrated: [DeviceConfig] = []
        
        if let data = defaults.data(forKey: "garageConfig"),
           let old = try? JSONDecoder().decode(V1Config.self, from: data),
           !old.ipAddress.isEmpty {
            migrated.append(DeviceConfig(
                id: UUID(), name: old.name, deviceType: .garage,
                ipAddress: old.ipAddress, apiSecretKey: old.apiSecretKey,
                apiAuthKey: old.apiAuthKey, accentColor: .blue, sortOrder: 0
            ))
        }
        
        if let data = defaults.data(forKey: "gateConfig"),
           let old = try? JSONDecoder().decode(V1Config.self, from: data),
           !old.ipAddress.isEmpty {
            migrated.append(DeviceConfig(
                id: UUID(), name: old.name, deviceType: .gate,
                ipAddress: old.ipAddress, apiSecretKey: old.apiSecretKey,
                apiAuthKey: old.apiAuthKey, accentColor: .orange, sortOrder: 1
            ))
        }
        
        if !migrated.isEmpty {
            devices = migrated
            defaults.removeObject(forKey: "garageConfig")
            defaults.removeObject(forKey: "gateConfig")
        }
    }
    
    private struct V1Config: Codable {
        let name: String
        let ipAddress: String
        let apiSecretKey: String
        let apiAuthKey: String
    }
}
