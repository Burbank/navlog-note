import SwiftUI

@main
struct QUICKLOGApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .statusBarHidden(false)
        }
    }
}
