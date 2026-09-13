import SwiftUI

@main
struct MasterMechanicApp: App {
    @StateObject private var progress = ProgressStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(progress)
                .environmentObject(purchases)
                .task {
                    // Hosted XCTest runs launch the app process. Skip storefront loading
                    // there so logic tests remain deterministic and fully offline.
                    if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                        await purchases.prepare()
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}
