import SwiftUI

@main
struct RemootioGateApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var controller = DeviceController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(controller)
        }
    }
}
