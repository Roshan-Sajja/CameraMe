import SwiftUI

struct RootView: View {
    @StateObject private var permissionManager = PermissionManager()
    @StateObject private var voiceViewModel = VoiceTriggerViewModel()
    @StateObject private var cameraController = CameraController()
    @State private var showSettings = false
    @State private var hasRequestedInitialPermissions = false
    @State private var showOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance_mode") private var appearanceMode: String = "Auto"
    @AppStorage("has_seen_onboarding") private var hasSeenOnboarding: Bool = false
    
    private var selectedColorScheme: ColorScheme? {
        switch appearanceMode {
        case "Light": return .light
        case "Dark": return .dark
        default: return nil
        }
    }
    
    var body: some View {
        CameraView(
            permissionManager: permissionManager,
            cameraController: cameraController,
            voiceViewModel: voiceViewModel,
            showSettings: $showSettings
        )
        .onAppear {
            bootstrapPermissions()
            if !hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showOnboarding = true
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshPermissionState()
                requestCameraPermissionIfNeeded()
                startCameraIfAuthorized()
                requestVoicePermissionsIfNeeded()
                requestPhotoLibraryPermissionIfNeeded()
            } else if phase == .background {
                cameraController.stopSession()
            }
        }
        .onChange(of: permissionManager.cameraStatus) { _, status in
            if status == .authorized {
                startCameraIfAuthorized()
            } else {
                cameraController.stopSession()
            }
        }
        .fullScreenCover(isPresented: $showSettings) {
            SettingsView(voiceViewModel: voiceViewModel, cameraController: cameraController)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(
                triggerPhrase: voiceViewModel.triggerPhrase,
                onDismiss: {
                    hasSeenOnboarding = true
                    showOnboarding = false
                }
            )
        }
        .preferredColorScheme(selectedColorScheme)
    }
}

private extension RootView {
    func bootstrapPermissions() {
        refreshPermissionState()
        
        guard !hasRequestedInitialPermissions else {
            startCameraIfAuthorized()
            return
        }
        
        hasRequestedInitialPermissions = true
        
        requestCameraPermissionIfNeeded()
        requestVoicePermissionsIfNeeded()
        requestPhotoLibraryPermissionIfNeeded()
    }
    
    func refreshPermissionState() {
        permissionManager.checkPermissions()
        voiceViewModel.refreshPermissions()
    }
    
    func requestCameraPermissionIfNeeded() {
        if permissionManager.cameraStatus == .notDetermined {
            permissionManager.requestCameraPermission { granted in
                if granted {
                    startCameraIfAuthorized()
                }
            }
        } else if permissionManager.cameraStatus == .authorized {
            startCameraIfAuthorized()
        }
    }
    
    func startCameraIfAuthorized() {
        if permissionManager.cameraStatus == .authorized && !cameraController.isSessionRunning {
            cameraController.startSession()
        }
    }
    
    func requestPhotoLibraryPermissionIfNeeded() {
        if permissionManager.photoLibraryStatus == .notDetermined {
            permissionManager.requestPhotoLibraryPermission { _ in }
        }
    }
    
    func requestVoicePermissionsIfNeeded() {
        voiceViewModel.requestPermissionsIfNeeded()
    }
}

#Preview {
    RootView()
        .preferredColorScheme(.dark)
}
