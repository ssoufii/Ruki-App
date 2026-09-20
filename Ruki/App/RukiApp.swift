import SwiftUI

@main
struct RukiApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
        }
    }
}
