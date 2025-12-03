import SwiftUI
import Photos
import UIKit

struct CameraView: View {
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var cameraController: CameraController
    @ObservedObject var voiceViewModel: VoiceTriggerViewModel
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    
    @StateObject private var orientationManager = DeviceOrientationManager()
    @State private var isCapturing = false
    @State private var showFlash = false
    @State private var capturedImage: UIImage?
    @State private var showCapturedPreview = false
    @State private var shutterScale: CGFloat = 1.0
    @State private var saveStatus: PhotoSaveStatus = .idle
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @State private var lastZoomFactor: CGFloat = 1.0
    @State private var lastProcessedTrigger: String?
    @State private var wasListeningBeforeBackground = false
    @State private var isTogglingVoice = false
    @State private var permissionAlertType: PermissionAlertType?
    
    private var controlsRotation: Angle {
        Angle(degrees: -orientationManager.rotationDegrees)
    }
    
    private var isCameraAuthorized: Bool {
        permissionManager.cameraStatus == .authorized
    }
    
    private var isCameraPermissionDenied: Bool {
        permissionManager.cameraStatus == .denied || permissionManager.cameraStatus == .restricted
    }
    
    var body: some View {
        GeometryReader { geometry in
            cameraContent(for: geometry)
        }
        .onAppear {
            if isCameraAuthorized {
                cameraController.startSession()
            }
            showRelevantPermissionAlertIfNeeded()
            checkPhotoLibraryPermission()
            lastZoomFactor = cameraController.zoomFactor
            cameraController.updateVideoOrientation(orientationManager.videoOrientation)
            voiceViewModel.refreshPermissions()
        }
        .onDisappear {
            cameraController.stopSession()
            voiceViewModel.stopListening()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if isCameraAuthorized {
                    cameraController.startSession()
                }
                checkPhotoLibraryPermission()
                if wasListeningBeforeBackground {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        voiceViewModel.startListening()
                    }
                }
            case .background, .inactive:
                wasListeningBeforeBackground = voiceViewModel.isListening
                cameraController.stopSession()
                voiceViewModel.stopListening()
            @unknown default:
                break
            }
        }
        .onReceive(voiceViewModel.$lastTriggerDescription) { trigger in
            if let trigger = trigger,
               trigger != lastProcessedTrigger,
               voiceViewModel.isListening,
               !isTogglingVoice,
               !voiceViewModel.isTestingMode,
               !showSettings {
                lastProcessedTrigger = trigger
                capturePhoto()
            }
        }
        .onReceive(orientationManager.$videoOrientation) { newOrientation in
            cameraController.updateVideoOrientation(newOrientation)
        }
        .onChange(of: permissionManager.cameraStatus) { _, newStatus in
            if newStatus == .authorized {
                cameraController.startSession()
                if permissionAlertType == .camera {
                    permissionAlertType = nil
                }
            } else if newStatus == .denied || newStatus == .restricted {
                permissionAlertType = .camera
                cameraController.stopSession()
            }
        }
        .onChange(of: voiceViewModel.microphonePermissionStatus) { _, status in
            if status.requiresSystemSettings {
                permissionAlertType = .microphone
            } else if status.isGranted && permissionAlertType == .microphone {
                permissionAlertType = nil
            }
        }
        .onChange(of: voiceViewModel.speechPermissionStatus) { _, status in
            if status.requiresSystemSettings {
                permissionAlertType = .speech
            } else if status.isGranted && permissionAlertType == .speech {
                permissionAlertType = nil
            }
        }
        .onChange(of: photoLibraryStatus) { _, status in
            if status == .authorized || status == .limited {
                permissionAlertType = nil
            }
        }
        .alert(item: $permissionAlertType) { alertType in
            Alert(
                title: Text(alertType.title),
                message: Text(alertType.message),
                primaryButton: .default(Text("Open Settings")) { openSystemSettings() },
                secondaryButton: .cancel()
            )
        }
        .fullScreenCover(isPresented: $showCapturedPreview) {
            if let image = capturedImage {
                PhotoPreviewView(image: image, isPresented: $showCapturedPreview)
            }
        }
    }
    
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
    
    @ViewBuilder
    private func cameraContent(for geometry: GeometryProxy) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "0f0c29"),
                    Color(hex: "302b63"),
                    Color(hex: "24243e")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            CameraPreviewView(cameraController: cameraController)
                .ignoresSafeArea()
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let newZoom = lastZoomFactor * value
                            cameraController.setZoom(newZoom)
                        }
                        .onEnded { _ in
                            lastZoomFactor = cameraController.zoomFactor
                        }
                )
            
            AspectRatioOverlay(
                aspectRatio: cameraController.aspectRatio,
                geometry: geometry
            )
            .ignoresSafeArea()
            .id(cameraController.aspectRatio.rawValue)
            
            if cameraController.showGridLines {
                GridOverlay(aspectRatio: cameraController.aspectRatio)
                    .ignoresSafeArea()
            }
            
            if showFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
            
            if cameraController.isTimerRunning {
                TimerCountdownOverlay(countdown: cameraController.timerCountdown)
            }
            
            VStack(spacing: 0) {
                TopControlsBar(
                    cameraController: cameraController,
                    voiceViewModel: voiceViewModel,
                    showSettings: $showSettings,
                    onVoiceToggle: {
                        isTogglingVoice = true
                        voiceViewModel.lastTranscription = nil
                        voiceViewModel.toggleListening()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isTogglingVoice = false
                        }
                    },
                    controlRotation: controlsRotation,
                    topPadding: max(geometry.safeAreaInsets.top - 25, 0)

                )
                
                Spacer()
                
                VStack(spacing: 16) {
                    if cameraController.zoomFactor != 1.0 {
                        ZoomIndicator(zoom: cameraController.zoomFactor)
                            .transition(.opacity)
                    }
                    
                    if cameraController.cameraPosition == .back && cameraController.availableLenses.count > 1 {
                        LensSelectorView(
                            cameraController: cameraController,
                            controlRotation: controlsRotation
                        )
                    }
                    
                    HStack(alignment: .top, spacing: 50) {
                        PhotoPreviewButton(image: capturedImage) {
                            if capturedImage != nil {
                                showCapturedPreview = true
                            }
                        }
                        .rotationEffect(controlsRotation)
                        .animation(.easeInOut(duration: 0.25), value: orientationManager.rotationDegrees)
                        
                        ShutterButton(
                            scale: shutterScale,
                            timerDuration: cameraController.timerDuration,
                            isTimerRunning: cameraController.isTimerRunning,
                            timerCountdown: cameraController.timerCountdown,
                            action: {
                                capturePhoto()
                            },
                            cancelAction: {
                                cameraController.cancelTimer()
                            }
                        )
                        .rotationEffect(controlsRotation)
                        .animation(.easeInOut(duration: 0.25), value: orientationManager.rotationDegrees)
                        
                        FlipButton {
                            cameraController.toggleCamera()
                        }
                        .rotationEffect(controlsRotation)
                        .animation(.easeInOut(duration: 0.25), value: orientationManager.rotationDegrees)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 50)
            }
            
            if saveStatus != .idle {
                VStack {
                    Spacer()
                    PhotoSaveToast(status: saveStatus)
                        .padding(.bottom, 200)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: saveStatus)
            }
        }
    }
    
    private func showRelevantPermissionAlertIfNeeded() {
        if isCameraPermissionDenied {
            permissionAlertType = .camera
        } else if voiceViewModel.microphonePermissionStatus.requiresSystemSettings {
            permissionAlertType = .microphone
        } else if voiceViewModel.speechPermissionStatus.requiresSystemSettings {
            permissionAlertType = .speech
        }
    }
    
    private func checkPhotoLibraryPermission() {
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
    }
    
    private func capturePhoto() {
        guard !isCapturing && !cameraController.isTimerRunning else {
            print("📷 Capture blocked - isCapturing: \(isCapturing), isTimerRunning: \(cameraController.isTimerRunning)")
            return
        }
        
        withAnimation(.spring(response: 0.15, dampingFraction: 0.5)) {
            shutterScale = 0.9
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                shutterScale = 1.0
            }
        }
        
        isCapturing = true
        print("📷 isCapturing set to true")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [self] in
            if isCapturing {
                print("📷 Safety timeout - resetting isCapturing")
                isCapturing = false
            }
        }
        
        withAnimation(.easeIn(duration: 0.1)) {
            showFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                showFlash = false
            }
        }
        
        print("📷 Calling capturePhoto, isCaptureReady: \(cameraController.isCaptureReady)")
        
        cameraController.capturePhoto { result in
            DispatchQueue.main.async {
                print("📷 Capture completion received, resetting isCapturing")
                isCapturing = false
                
                switch result {
                case .success(let captureResult):
                    print("📷 Capture success! Data size: \(captureResult.imageData.count) bytes")
                    if let image = UIImage(data: captureResult.imageData) {
                        let finalImage: UIImage
                        let finalImageData: Data
                        
                        if let croppedImage = cropImage(image, to: cameraController.aspectRatio) {
                            finalImage = croppedImage
                            finalImageData = croppedImage.jpegData(compressionQuality: 0.95) ?? captureResult.imageData
                        } else {
                            finalImage = image
                            finalImageData = captureResult.imageData
                        }
                        
                        capturedImage = finalImage
                        savePhotoToLibrary(imageData: finalImageData)
                    } else {
                        print("📷 Failed to create UIImage from data")
                        showSaveStatus(.error("Invalid image data"))
                    }
                case .failure(let error):
                    print("📷 Capture failed: \(error.localizedDescription)")
                    showSaveStatus(.error("Capture failed: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func cropImage(_ image: UIImage, to aspectRatio: AspectRatio) -> UIImage? {
        // First normalize the image orientation so pixels match visual orientation
        let normalizedImage = normalizeOrientation(image)
        guard let cgImage = normalizedImage.cgImage else { return nil }
        
        let cgWidth = CGFloat(cgImage.width)
        let cgHeight = CGFloat(cgImage.height)
        
        // After normalization, width > height means landscape, height > width means portrait
        let isLandscape = cgWidth > cgHeight
        
        let targetRatio: CGFloat
        
        switch aspectRatio {
        case .ratio4x3:
            return normalizedImage
        case .ratio1x1:
            targetRatio = 1.0
        case .ratio16x9:
            targetRatio = 16.0 / 9.0
        }
        
        var cropRect: CGRect
        
        if isLandscape {
            // Landscape: width is the long side
            let currentRatio = cgWidth / cgHeight
            if targetRatio > currentRatio {
                // Need to crop height
                let newHeight = cgWidth / targetRatio
                let yOffset = (cgHeight - newHeight) / 2
                cropRect = CGRect(x: 0, y: yOffset, width: cgWidth, height: newHeight)
            } else {
                // Need to crop width
                let newWidth = cgHeight * targetRatio
                let xOffset = (cgWidth - newWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: cgHeight)
            }
        } else {
            // Portrait: height is the long side
            let currentRatio = cgHeight / cgWidth
            if targetRatio > currentRatio {
                // Need to crop width
                let newWidth = cgHeight / targetRatio
                let xOffset = (cgWidth - newWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: cgHeight)
            } else {
                // Need to crop height
                let newHeight = cgWidth * targetRatio
                let yOffset = (cgHeight - newHeight) / 2
                cropRect = CGRect(x: 0, y: yOffset, width: cgWidth, height: newHeight)
            }
        }
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        
        return UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: .up)
    }
    
    private func normalizeOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        
        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? image
    }
    
    private func savePhotoToLibrary(imageData: Data) {
        print("📸 Attempting to save photo, data size: \(imageData.count) bytes")
        
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        print("📸 Photo library status: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            print("📸 Permission granted, saving...")
            performSave(imageData: imageData)
        case .notDetermined:
            print("📸 Permission not determined, requesting...")
            showSaveStatus(.saving)
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                print("📸 Permission response: \(newStatus.rawValue)")
                DispatchQueue.main.async {
                    self.photoLibraryStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(imageData: imageData)
                    } else {
                        self.showSaveStatus(.error("Photo access denied"))
                    }
                }
            }
        case .denied, .restricted:
            print("📸 Permission denied")
            showSaveStatus(.error("Enable Photos access in Settings"))
        @unknown default:
            print("📸 Unknown permission status")
            showSaveStatus(.error("Unknown error"))
        }
    }
    
    private func performSave(imageData: Data) {
        print("📸 performSave called")
        showSaveStatus(.saving)
        
        PHPhotoLibrary.shared().performChanges {
            print("📸 Creating asset...")
            let creationRequest = PHAssetCreationRequest.forAsset()
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            creationRequest.addResource(with: .photo, data: imageData, options: photoOptions)
        } completionHandler: { success, error in
            print("📸 Save result - success: \(success), error: \(error?.localizedDescription ?? "none")")
            
            DispatchQueue.main.async {
                if success {
                    self.showSaveStatus(.saved)
                } else {
                    self.showSaveStatus(.error(error?.localizedDescription ?? "Save failed"))
                }
            }
        }
    }
    
    private func showSaveStatus(_ status: PhotoSaveStatus) {
        withAnimation {
            saveStatus = status
        }
        
        if status == .saved || status.isError {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    saveStatus = .idle
                }
            }
        }
    }
}

private struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    private var isZoomedIn: Bool {
        scale > 1.0
    }
    
    private func clampedOffset(for geometry: GeometryProxy, proposedOffset: CGSize) -> CGSize {
        let imageAspect = image.size.width / image.size.height
        let frameAspect = geometry.size.width / geometry.size.height
        
        let imageWidth: CGFloat
        let imageHeight: CGFloat
        
        if imageAspect > frameAspect {
            imageWidth = geometry.size.width
            imageHeight = geometry.size.width / imageAspect
        } else {
            imageHeight = geometry.size.height
            imageWidth = geometry.size.height * imageAspect
        }
        
        let scaledWidth = imageWidth * scale
        let scaledHeight = imageHeight * scale
        
        let maxOffsetX = max(0, (scaledWidth - geometry.size.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - geometry.size.height) / 2)
        
        return CGSize(
            width: min(max(proposedOffset.width, -maxOffsetX), maxOffsetX),
            height: min(max(proposedOffset.height, -maxOffsetY), maxOffsetY)
        )
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = lastScale * value
                            }
                            .onEnded { _ in
                                lastScale = scale
                                if scale < 1.0 {
                                    withAnimation(.spring()) {
                                        scale = 1.0
                                        lastScale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    }
                                } else {
                                    let clamped = clampedOffset(for: geometry, proposedOffset: offset)
                                    if clamped != offset {
                                        withAnimation(.spring()) {
                                            offset = clamped
                                            lastOffset = clamped
                                        }
                                    }
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture()
                            .onChanged { value in
                                guard isZoomedIn else { return }
                                let proposed = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                                offset = clampedOffset(for: geometry, proposedOffset: proposed)
                            }
                            .onEnded { _ in
                                guard isZoomedIn else { return }
                                lastOffset = offset
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            scale = 1.0
                            lastScale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    }
            }
            
            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .padding()
            }
        }
    }
}

private enum PermissionAlertType: String, Identifiable {
    case camera
    case microphone
    case speech
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .camera: return "Camera Access Needed"
        case .microphone: return "Microphone Access Needed"
        case .speech: return "Speech Recognition Needed"
        }
    }
    
    var message: String {
        switch self {
        case .camera:
            return "Enable camera access in Settings to show the live preview and capture photos."
        case .microphone:
            return "Enable microphone access in Settings so voice capture can work."
        case .speech:
            return "Enable speech recognition in Settings to use voice commands."
        }
    }
}
