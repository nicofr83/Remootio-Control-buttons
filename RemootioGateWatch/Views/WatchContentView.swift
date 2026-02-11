import SwiftUI
#if os(watchOS)
import WatchKit
#endif

struct WatchContentView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var controller: DeviceController
    
    var body: some View {
        if !settings.isConfigured {
            VStack(spacing: 8) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Configure devices\nin iPhone app")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    // Dynamic device buttons
                    ForEach(settings.configuredDevices) { device in
                        let client = controller.client(for: device.id)
                        let status = client?.gateStatus ?? .unknown
                        let connState = client?.connectionState ?? .disconnected
                        let isLoading = controller.isActionInProgress(for: device.id)
                        
                        WatchGateButton(
                            config: device,
                            status: status,
                            connectionState: connState,
                            isLoading: isLoading
                        ) {
                            triggerHaptic(.click)
                            controller.toggle(deviceID: device.id)
                        } onQuery: {
                            triggerHaptic(.directionUp)
                            controller.queryStatus(deviceID: device.id)
                        } onForceOpen: {
                            triggerHaptic(.success)
                            controller.forceOpen(deviceID: device.id)
                        } onForceClose: {
                            triggerHaptic(.success)
                            controller.forceClose(deviceID: device.id)
                        }
                    }
                    
                    // Reconnect
                    Button {
                        triggerHaptic(.click)
                        controller.connectAll()
                    } label: {
                        Label("Reconnect", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.top, 6)
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Remootio")
        }
    }
    
    private func triggerHaptic(_ type: WKHapticType) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(type)
        #endif
    }
}

// MARK: - Watch Gate Button (optimized for small screen + haptic context menu)

struct WatchGateButton: View {
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
        case .open: return "OPEN"
        case .closed: return "CLOSED"
        case .noSensor: return "NO SENSOR"
        case .unknown: return "—"
        }
    }
    
    /// Dynamic icon: changes between open/closed states
    private var currentIcon: String {
        config.icon(for: status)
    }
    
    /// Bold status color (high contrast for Apple Watch)
    private var statusColor: Color {
        switch status {
        case .open:   return .green
        case .closed: return .red
        default:      return .gray
        }
    }
    
    /// Background intensity based on state
    private var bgOpacity: Double {
        isReady ? 0.25 : 0.10
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Large dynamic icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(config.accentColor.color.opacity(bgOpacity))
                        .frame(width: 44, height: 44)
                    
                    if isLoading {
                        ProgressView()
                    } else {
                        Image(systemName: currentIcon)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(isReady ? config.accentColor.color : .gray)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(config.name)
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isReady ? statusColor : .gray)
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.system(.caption2, weight: .bold))
                            .foregroundColor(isReady ? statusColor : .gray)
                    }
                }
                
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(config.accentColor.color.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(
                                status == .open ? Color.green.opacity(0.4) :
                                    (status == .closed ? Color.red.opacity(0.3) : Color.clear),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!isReady || isLoading)
        // MARK: Long-press context menu with haptic feedback
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
    WatchContentView()
        .environmentObject(SettingsStore.shared)
        .environmentObject(DeviceController())
}
