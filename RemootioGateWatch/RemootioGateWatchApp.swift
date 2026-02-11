import SwiftUI

@main
struct RemootioGateWatchApp: App {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var controller = DeviceController()
    
    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(settings)
                .environmentObject(controller)
                .onAppear {
                    if settings.isConfigured {
                        controller.setupClients()
                        controller.connectAll()
                    }
                }
        }
    }
}
