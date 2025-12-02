import SwiftUI

@main
struct CameraMeApp: App {
    @AppStorage("appearance_mode") private var appearanceMode: String = "Auto"
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(colorScheme)
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
}
