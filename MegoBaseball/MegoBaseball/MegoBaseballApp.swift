import SwiftUI

@main
struct MegoBaseballApp: App {
    @StateObject private var settings: GameSettings
    @StateObject private var game: GameController

    init() {
        let settings = GameSettings()
        _settings = StateObject(wrappedValue: settings)
        _game = StateObject(wrappedValue: GameController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(game)
                .preferredColorScheme(.dark)
                .statusBarHidden()
        }
    }
}
