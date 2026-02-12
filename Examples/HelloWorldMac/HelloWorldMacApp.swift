import SwiftUI
import Aptabase

@main
struct HelloWorldMacApp: App {
    init() {
        Aptabase.shared.initialize(
            appKey: "A-DEV-0000000000",
            with: InitOptions(trackingMode: .release)
        )
    }

    var body: some Scene {
        WindowGroup {
            CounterView()
        }
    }
}
