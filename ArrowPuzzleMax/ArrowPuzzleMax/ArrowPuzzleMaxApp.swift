import SwiftUI

@main
struct ArrowPuzzleMaxApp: App {
    @StateObject private var store = ProgressStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
