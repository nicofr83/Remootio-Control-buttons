import SwiftUI

// MARK: - Main Settings View (device list)

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @Environment(\.dismiss) var dismiss
    @State private var editingDevice: DeviceConfig?
    @State private var showDeleteConfirm: UUID?
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Devices Section
                Section {
                    if settings.devices.isEmpty {
                        HStack {
                            Spacer()
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.dashed")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("No devices configured")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 20)
                            Spacer()
                        }
                    } else {
                        ForEach(settings.devices) { device in
                            Button {
                                editingDevice = device
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: device.deviceType.closedIcon)
                                        .font(.title3)
                                        .foregroundColor(device.accentColor.color)
                                        .frame(width: 36)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(device.name.isEmpty ? "Untitled Device" : device.name)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                        Text(device.ipAddress.isEmpty ? "Not configured" : device.ipAddress)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Validation indicator
                                    Image(systemName: device.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(device.isValid ? .green : .orange)
                                        .font(.caption)
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    settings.removeDevice(id: device.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove { source, destination in
                            settings.moveDevice(from: source, to: destination)
                        }
                    }
                } header: {
                    HStack {
                        Text("Devices")
                        Spacer()
                        Button {
                            let newDevice = settings.addDevice()
                            editingDevice = newDevice
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.caption)
                        }
                    }
                } footer: {
                    Text("Tap a device to edit. Swipe left to delete. Drag to reorder.")
                }
                
                // MARK: - Help Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("How to get API keys", systemImage: "info.circle")
                            .font(.subheadline.bold())
                        
                        Text("1. Open the Remootio app on your phone")
                        Text("2. Select your device")
                        Text("3. Go to Device Software → API settings")
                        Text("4. Enable the Websocket API")
                        Text("5. Copy the API Secret Key and API Auth Key")
                        Text("6. Note the device IP address")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } header: {
                    Text("Help")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("0.2")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingDevice) { device in
                DeviceEditView(device: device) { updated in
                    settings.updateDevice(updated)
                }
            }
        }
    }
}

// MARK: - Device Edit View (full form for one device)

struct DeviceEditView: View {
    @Environment(\.dismiss) var dismiss
    
    let originalDevice: DeviceConfig
    let onSave: (DeviceConfig) -> Void
    
    @State private var name: String
    @State private var deviceType: DeviceType
    @State private var ipAddress: String
    @State private var apiSecretKey: String
    @State private var apiAuthKey: String
    @State private var accentColor: DeviceColor
    @State private var showSaved = false
    
    init(device: DeviceConfig, onSave: @escaping (DeviceConfig) -> Void) {
        self.originalDevice = device
        self.onSave = onSave
        _name = State(initialValue: device.name)
        _deviceType = State(initialValue: device.deviceType)
        _ipAddress = State(initialValue: device.ipAddress)
        _apiSecretKey = State(initialValue: device.apiSecretKey)
        _apiAuthKey = State(initialValue: device.apiAuthKey)
        _accentColor = State(initialValue: device.accentColor)
    }
    
    private var isValid: Bool {
        !name.isEmpty && !ipAddress.isEmpty && apiSecretKey.count == 64 && apiAuthKey.count == 64
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Identity
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Name")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. Garage Door", text: $name)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Device Type")
                            .font(.caption).foregroundStyle(.secondary)
                        Picker("Type", selection: $deviceType) {
                            ForEach(DeviceType.allCases) { type in
                                Label(type.displayName, systemImage: type.closedIcon)
                                    .tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .onChange(of: deviceType) { _, newType in
                        accentColor = newType.defaultColor
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                            .font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                            ForEach(DeviceColor.allCases) { color in
                                Circle()
                                    .fill(color.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: accentColor == color ? 3 : 0)
                                    )
                                    .onTapGesture { accentColor = color }
                            }
                        }
                    }
                    
                    // Preview
                    HStack(spacing: 16) {
                        Text("Preview:")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        VStack(spacing: 4) {
                            Image(systemName: deviceType.closedIcon)
                                .font(.title2)
                                .foregroundColor(accentColor.color)
                            Text("Closed")
                                .font(.caption2)
                        }
                        VStack(spacing: 4) {
                            Image(systemName: deviceType.openIcon)
                                .font(.title2)
                                .foregroundColor(accentColor.color)
                            Text("Open")
                                .font(.caption2)
                        }
                    }
                } header: {
                    Text("Identity")
                }
                
                // MARK: - Connection
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IP Address")
                            .font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 192.168.1.100", text: $ipAddress)
                            .keyboardType(.decimalPad)
                            .textContentType(.none)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Connection")
                }
                
                // MARK: - API Keys
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API Secret Key")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(apiSecretKey.count)/64")
                                .font(.caption2)
                                .foregroundColor(apiSecretKey.count == 64 ? .green : .orange)
                        }
                        TextField("64-character hex string", text: $apiSecretKey)
                            .font(.system(.caption, design: .monospaced))
                            .textContentType(.none)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("API Auth Key")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(apiAuthKey.count)/64")
                                .font(.caption2)
                                .foregroundColor(apiAuthKey.count == 64 ? .green : .orange)
                        }
                        TextField("64-character hex string", text: $apiAuthKey)
                            .font(.system(.caption, design: .monospaced))
                            .textContentType(.none)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("API Credentials")
                } footer: {
                    Text("Find these in the Remootio app → Device → Websocket API settings. Both keys are 64-character hexadecimal strings.")
                }
                
                // Validation summary
                if !isValid {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            if name.isEmpty {
                                Label("Name is required", systemImage: "exclamationmark.triangle")
                            }
                            if ipAddress.isEmpty {
                                Label("IP address is required", systemImage: "exclamationmark.triangle")
                            }
                            if apiSecretKey.count != 64 {
                                Label("API Secret Key must be exactly 64 hex characters", systemImage: "exclamationmark.triangle")
                            }
                            if apiAuthKey.count != 64 {
                                Label("API Auth Key must be exactly 64 hex characters", systemImage: "exclamationmark.triangle")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            }
            .navigationTitle(name.isEmpty ? "New Device" : name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveDevice() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .overlay {
                if showSaved {
                    VStack {
                        Spacer()
                        Label("Saved", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .padding()
                            .background(.green.opacity(0.9))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                    .animation(.spring(), value: showSaved)
                }
            }
        }
    }
    
    private func saveDevice() {
        let updated = DeviceConfig(
            id: originalDevice.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            deviceType: deviceType,
            ipAddress: ipAddress.trimmingCharacters(in: .whitespacesAndNewlines),
            apiSecretKey: apiSecretKey.trimmingCharacters(in: .whitespacesAndNewlines),
            apiAuthKey: apiAuthKey.trimmingCharacters(in: .whitespacesAndNewlines),
            accentColor: accentColor,
            sortOrder: originalDevice.sortOrder
        )
        onSave(updated)
        
        showSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSaved = false
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(SettingsStore.shared)
}
