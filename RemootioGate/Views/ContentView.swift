import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var controller: DeviceController
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                    startPoint: .top, endPoint: .bottom
                ).ignoresSafeArea()
                
                if !settings.isConfigured {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("RemootioGate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settings)
            }
            .onAppear {
                if settings.isConfigured {
                    controller.setupClients()
                    controller.connectAll()
                }
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("Welcome to RemootioGate")
                .font(.title2.bold())
            
            Text("Add your Remootio devices\nto get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            Button {
                showSettings = true
            } label: {
                Label("Configure Devices", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: 280)
                    .background(.blue)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
    }
    
    // MARK: - Device List
    
    private var deviceListView: some View {
        VStack(spacing: 16) {
            // Connection status summary
            HStack {
                let connectedCount = settings.configuredDevices.filter {
                    controller.client(for: $0.id)?.connectionState == .authenticated
                }.count
                let total = settings.configuredDevices.count
                
                Circle()
                    .fill(connectedCount == total ? .green : (connectedCount > 0 ? .yellow : .red))
                    .frame(width: 8, height: 8)
                Text("\(connectedCount)/\(total) connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button {
                    let anyConnected = settings.configuredDevices.contains {
                        controller.client(for: $0.id)?.connectionState == .authenticated
                    }
                    if anyConnected { controller.disconnectAll() }
                    else { controller.connectAll() }
                } label: {
                    let anyConnected = settings.configuredDevices.contains {
                        controller.client(for: $0.id)?.connectionState == .authenticated
                    }
                    Label(anyConnected ? "Disconnect" : "Connect",
                          systemImage: anyConnected ? "wifi.slash" : "wifi")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Dynamic device buttons
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(settings.configuredDevices) { device in
                        let client = controller.client(for: device.id)
                        let status = client?.gateStatus ?? .unknown
                        let connState = client?.connectionState ?? .disconnected
                        let isLoading = controller.isActionInProgress(for: device.id)
                        
                        GateButton(
                            config: device,
                            status: status,
                            connectionState: connState,
                            isLoading: isLoading
                        ) {
                            controller.toggle(deviceID: device.id)
                        } onQuery: {
                            controller.queryStatus(deviceID: device.id)
                        } onForceOpen: {
                            controller.forceOpen(deviceID: device.id)
                        } onForceClose: {
                            controller.forceClose(deviceID: device.id)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Gate Button with Context Menu

struct GateButton: View {
    let config: DeviceConfig
    let status: RemootioClient.GateStatus
    let connectionState: RemootioClient.ConnectionState
    let isLoading: Bool
    let action: () -> Void
    let onQuery: () -> Void
    let onForceOpen: () -> Void
    let onForceClose: () -> Void
    
    private var isReady: Bool { connectionState == .authenticated }
    
    private var statusText: String {
        if !isReady { return connectionState.rawValue }
        switch status {
        case .open: return "Open"
        case .closed: return "Closed"
        case .noSensor: return "No Sensor"
        case .unknown: return "Unknown"
        }
    }
    
    private var actionLabel: String {
        switch status {
        case .open: return "Tap to Close"
        case .closed: return "Tap to Open"
        default: return "Tap to Trigger"
        }
    }
    
    /// Dynamic icon based on current status
    private var currentIcon: String {
        config.icon(for: status)
    }
    
    /// Status indicator color
    private var statusColor: Color {
        switch status {
        case .open:   return .green
        case .closed: return .red
        default:      return .secondary
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Dynamic icon circle
                ZStack {
                    Circle()
                        .fill(config.accentColor.color.opacity(isReady ? 0.2 : 0.08))
                        .frame(width: 64, height: 64)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: currentIcon)
                            .font(.system(size: 26, weight: .medium))
                            .foregroundColor(isReady ? config.accentColor.color : .secondary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(config.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .font(.subheadline)
                    }
                    .foregroundColor(statusColor)
                    
                    if isReady {
                        Text(actionLabel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
            }
            .padding(16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .disabled(!isReady || isLoading)
        .sensoryFeedback(.impact(weight: .medium), trigger: isLoading)
        // MARK: Context Menu (long-press haptic menu)
        .contextMenu {
            Button {
                onQuery()
            } label: {
                Label("Get Status", systemImage: "arrow.triangle.2.circlepath")
            }
            
            Button {
                onForceOpen()
            } label: {
                Label("Force Open", systemImage: "lock.open.fill")
            }
            
            Button {
                onForceClose()
            } label: {
                Label("Force Close", systemImage: "lock.fill")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore.shared)
        .environmentObject(DeviceController())
}
