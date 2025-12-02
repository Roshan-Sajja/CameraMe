import SwiftUI
import AVFoundation
import Photos
import Speech

final class PermissionManager: ObservableObject {
    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: VoicePermissionStatus = .notDetermined
    @Published var speechStatus: VoicePermissionStatus = .notDetermined
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    
    var allPermissionsGranted: Bool {
        cameraStatus == .authorized && microphoneStatus.isGranted && speechStatus.isGranted
    }
    
    var canSavePhotos: Bool {
        photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }
    
    var anyPermissionDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted ||
        microphoneStatus.requiresSystemSettings || speechStatus.requiresSystemSettings
    }
    
    func checkPermissions() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        if #available(iOS 17, *) {
            microphoneStatus = VoicePermissionStatus(appRecordPermission: AVAudioApplication.shared.recordPermission)
        } else {
            microphoneStatus = VoicePermissionStatus(recordPermission: AVAudioSession.sharedInstance().recordPermission)
        }
        
        speechStatus = VoicePermissionStatus(speechStatus: SFSpeechRecognizer.authorizationStatus())
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    func requestCameraPermission() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraStatus = granted ? .authorized : .denied
            }
        }
    }
    
    func requestMicrophonePermission() {
        let completion: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                self?.microphoneStatus = granted ? .granted : .denied
            }
        }
        
        if #available(iOS 17, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                completion(allowed)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                completion(allowed)
            }
        }
    }
    
    func requestSpeechPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechStatus = VoicePermissionStatus(speechStatus: status)
            }
        }
    }
    
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    func requestAllPermissions() {
        requestCameraPermission()
        requestMicrophonePermission()
        requestSpeechPermission()
        requestPhotoLibraryPermission { _ in }
    }
}

