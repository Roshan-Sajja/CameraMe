import SwiftUI

@main
struct VoiceCameraApp: App {
    var body: some Scene {
        WindowGroup {
            PlaceholderView()
        }
    }
}

struct PlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Voice Camera App")
                .font(.largeTitle)
                .bold()

            Text("App scaffolding is in place. Implementation coming soon.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            ProgressView("Preparing audio & camera pipelines…")
        }
        .padding()
    }
}
