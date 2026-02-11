import Foundation
import Combine

// MARK: - Device Controller ViewModel (dynamic N devices)

class DeviceController: ObservableObject {
    
    /// Map of device UUID → RemootioClient
    @Published var clients: [UUID: RemootioClient] = [:]
    
    /// Map of device UUID → action in progress
    @Published var actionInProgress: [UUID: Bool] = [:]
    
    /// Map of device UUID → last action result
    @Published var lastResults: [UUID: ActionResult] = [:]
    
    struct ActionResult {
        let success: Bool
        let message: String
        let timestamp: Date
    }
    
    private let settings: SettingsStore
    private var cancellables = Set<AnyCancellable>()
    
    init(settings: SettingsStore = .shared) {
        self.settings = settings
        setupClients()
        
        // Rebuild clients when devices change
        settings.$devices
            .dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in self?.setupClients() }
            .store(in: &cancellables)
    }
    
    // MARK: - Client Management
    
    func setupClients() {
        // Disconnect removed devices
        let validIDs = Set(settings.configuredDevices.map { $0.id })
        for (id, client) in clients where !validIDs.contains(id) {
            client.disconnect()
            clients.removeValue(forKey: id)
        }
        
        // Create/update clients for configured devices
        for device in settings.configuredDevices {
            if clients[device.id] == nil {
                let client = RemootioClient(
                    deviceIP: device.ipAddress,
                    apiSecretKey: device.apiSecretKey,
                    apiAuthKey: device.apiAuthKey,
                    deviceName: device.name
                )
                clients[device.id] = client
            }
        }
    }
    
    func connectAll() {
        for client in clients.values {
            client.connect()
        }
    }
    
    func disconnectAll() {
        for client in clients.values {
            client.disconnect()
        }
    }
    
    func client(for deviceID: UUID) -> RemootioClient? {
        clients[deviceID]
    }
    
    func isActionInProgress(for deviceID: UUID) -> Bool {
        actionInProgress[deviceID] ?? false
    }
    
    // MARK: - Smart Toggle (auto open/close based on current status)
    
    func toggle(deviceID: UUID) {
        guard let client = clients[deviceID] else { return }
        actionInProgress[deviceID] = true
        
        switch client.gateStatus {
        case .open:
            client.sendClose { [weak self] success, error in
                self?.handleResult(deviceID: deviceID, success: success,
                                   message: success ? "Closing…" : (error ?? "Failed"))
            }
        case .closed:
            client.sendOpen { [weak self] success, error in
                self?.handleResult(deviceID: deviceID, success: success,
                                   message: success ? "Opening…" : (error ?? "Failed"))
            }
        default:
            client.sendTrigger { [weak self] success, error in
                self?.handleResult(deviceID: deviceID, success: success,
                                   message: success ? "Triggered" : (error ?? "Failed"))
            }
        }
    }
    
    // MARK: - Force Actions (context menu)
    
    func forceOpen(deviceID: UUID) {
        guard let client = clients[deviceID] else { return }
        actionInProgress[deviceID] = true
        client.sendOpen { [weak self] success, error in
            self?.handleResult(deviceID: deviceID, success: success,
                               message: success ? "Opening…" : (error ?? "Failed"))
        }
    }
    
    func forceClose(deviceID: UUID) {
        guard let client = clients[deviceID] else { return }
        actionInProgress[deviceID] = true
        client.sendClose { [weak self] success, error in
            self?.handleResult(deviceID: deviceID, success: success,
                               message: success ? "Closing…" : (error ?? "Failed"))
        }
    }
    
    func queryStatus(deviceID: UUID) {
        guard let client = clients[deviceID] else { return }
        actionInProgress[deviceID] = true
        client.sendQuery { [weak self] success, error in
            self?.handleResult(deviceID: deviceID, success: success,
                               message: success ? "Status updated" : (error ?? "Failed"))
        }
    }
    
    // MARK: - Result Handler
    
    private func handleResult(deviceID: UUID, success: Bool, message: String) {
        DispatchQueue.main.async {
            self.actionInProgress[deviceID] = false
            self.lastResults[deviceID] = ActionResult(
                success: success, message: message, timestamp: Date()
            )
        }
    }
}
