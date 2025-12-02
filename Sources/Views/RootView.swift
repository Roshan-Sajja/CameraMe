import SwiftUI

struct RootView: View {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var voiceViewModel = VoiceTriggerViewModel()
    @StateObject private var cameraController = CameraController()
    @State private var showSettings = false
    
    var body: some View {
        ZStack {
            if permissionManager.allPermissionsGranted {
                CameraView(
                    cameraController: cameraController,
                    voiceViewModel: voiceViewModel,
                    showSettings: $showSettings
                )
            } else if permissionManager.anyPermissionDenied {
                PermissionDeniedView(permissionManager: permissionManager)
            } else {
                PermissionRequestView(permissionManager: permissionManager)
            }
        }
        .onAppear {
            permissionManager.checkPermissions()
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(voiceViewModel: voiceViewModel, cameraController: cameraController)
        }
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}

