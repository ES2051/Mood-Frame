import SwiftUI

@main
struct MoodFrameApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var moodStore = MoodStore()
    @StateObject private var bleManager = BLEManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(moodStore)
                .environmentObject(bleManager)
        }
    }
}
