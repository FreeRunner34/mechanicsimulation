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
                .task { await purchases.prepare() }
                .preferredColorScheme(.dark)
        }
    }
}
