import SwiftUI
import Photos

struct CameraView: View {
    @ObservedObject var cameraController: CameraController
    @ObservedObject var voiceViewModel: VoiceTriggerViewModel
    @Binding var showSettings: Bool
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var isCapturing = false
    @State private var showFlash = false
    @State private var capturedImage: UIImage?
    @State private var showCapturedPreview = false
    @State private var shutterScale: CGFloat = 1.0
    @State private var saveStatus: PhotoSaveStatus = .idle
    @State private var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @State private var showAspectRatioMenu = false
    @State private var lastZoomFactor: CGFloat = 1.0
    @State private var lastProcessedTrigger: String?
    @State private var hasAutoStartedVoice = false
    @State private var wasListeningBeforeBackground = false
    @State private var isTogglingVoice = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
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
                
                // Camera preview
                CameraPreviewView(cameraController: cameraController)
                    .ignoresSafeArea()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                let newZoom = lastZoomFactor * value
                                cameraController.setZoom(newZoom)
                            }
                            .onEnded { value in
                                lastZoomFactor = cameraController.zoomFactor
                            }
                    )
                
                // Aspect ratio overlay
                AspectRatioOverlay(
                    aspectRatio: cameraController.aspectRatio,
                    geometry: geometry
                )
                .ignoresSafeArea()
                .id(cameraController.aspectRatio.rawValue)
                
                // Grid lines overlay
                if cameraController.showGridLines {
                    GridOverlay(aspectRatio: cameraController.aspectRatio)
                        .ignoresSafeArea()
                }
                
                // Flash overlay
                if showFlash {
                    Color.white
                        .ignoresSafeArea()
                        .transition(.opacity)
                }
                
                // Timer countdown overlay
                if cameraController.isTimerRunning {
                    TimerCountdownOverlay(countdown: cameraController.timerCountdown)
                }
                
                // UI Overlay
                VStack(spacing: 0) {
                    // Top controls
                    TopControlsBar(
                        cameraController: cameraController,
                        voiceViewModel: voiceViewModel,
                        showSettings: $showSettings
                    ) {
                        isTogglingVoice = true
                        // Clear accumulated transcription when toggling
                        voiceViewModel.lastTranscription = nil
                        voiceViewModel.toggleListening()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            isTogglingVoice = false
                        }
                    }
                    
                    Spacer()
                    
                    // Bottom controls
                    VStack(spacing: 16) {
                        // Zoom indicator
                        if cameraController.zoomFactor != 1.0 {
                            ZoomIndicator(zoom: cameraController.zoomFactor)
                                .transition(.opacity)
                        }
                        
                        // Lens selector (for back camera only)
                        if cameraController.cameraPosition == .back && cameraController.availableLenses.count > 1 {
                            LensSelectorView(cameraController: cameraController)
                        }
                        
                        // Main control row: Preview, Shutter, Flip
                        HStack(alignment: .top, spacing: 50) {
                            // Photo preview button
                            PhotoPreviewButton(image: capturedImage) {
                                if capturedImage != nil {
                                    showCapturedPreview = true
                                }
                            }
                            
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
                            
                            FlipButton {
                                cameraController.toggleCamera()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
                
                // Save status toast
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
        .onAppear {
            cameraController.startSession()
            checkPhotoLibraryPermission()
            lastZoomFactor = cameraController.zoomFactor
        }
        .onDisappear {
            cameraController.stopSession()
            voiceViewModel.stopListening()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                cameraController.startSession()
                checkPhotoLibraryPermission()
                if wasListeningBeforeBackground && !voiceViewModel.isListening {
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
        .onChange(of: cameraController.isCaptureReady) { _, isReady in
            if isReady && !hasAutoStartedVoice {
                hasAutoStartedVoice = true
                print("🎤 Camera ready, starting voice listener...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    voiceViewModel.refreshPermissions()
                    if !voiceViewModel.isListening {
                        voiceViewModel.startListening()
                    }
                }
            }
        }
        .onReceive(voiceViewModel.$lastTriggerDescription) { trigger in
            if let trigger = trigger,
               trigger != lastProcessedTrigger,
               voiceViewModel.isListening,
               !isTogglingVoice,
               !voiceViewModel.isTestingMode {
                lastProcessedTrigger = trigger
                capturePhoto()
            }
        }
        .fullScreenCover(isPresented: $showCapturedPreview) {
            if let image = capturedImage {
                PhotoPreviewView(image: image, isPresented: $showCapturedPreview)
            }
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
        
        // Safety timeout to reset isCapturing if completion never fires
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
                    print("📷 Capture success! Data size: \(captureResult.imageData.count) bytes, isLivePhoto: \(captureResult.isLivePhoto)")
                    if let image = UIImage(data: captureResult.imageData) {
                        let finalImage: UIImage
                        let finalImageData: Data
                        
                        if !captureResult.isLivePhoto, let croppedImage = cropImage(image, to: cameraController.aspectRatio) {
                            finalImage = croppedImage
                            finalImageData = croppedImage.jpegData(compressionQuality: 0.95) ?? captureResult.imageData
                        } else {
                            finalImage = image
                            finalImageData = captureResult.imageData
                        }
                        
                        capturedImage = finalImage
                        
                        let modifiedResult = CaptureResult(
                            imageData: finalImageData,
                            livePhotoMovieURL: captureResult.livePhotoMovieURL
                        )
                        savePhotoToLibrary(captureResult: modifiedResult)
                    } else {
                        print("📷 Failed to create UIImage from data")
                        showSaveStatus(.error("Invalid image data"))
                        if let movieURL = captureResult.livePhotoMovieURL {
                            try? FileManager.default.removeItem(at: movieURL)
                        }
                    }
                case .failure(let error):
                    print("📷 Capture failed: \(error.localizedDescription)")
                    showSaveStatus(.error("Capture failed: \(error.localizedDescription)"))
                }
            }
        }
    }
    
    private func cropImage(_ image: UIImage, to aspectRatio: AspectRatio) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let cgWidth = CGFloat(cgImage.width)
        let cgHeight = CGFloat(cgImage.height)
        
        let isRotated = image.imageOrientation == .left || 
                        image.imageOrientation == .right ||
                        image.imageOrientation == .leftMirrored ||
                        image.imageOrientation == .rightMirrored
        
        let targetRatio: CGFloat
        let cameraRatio: CGFloat = 4.0 / 3.0
        
        switch aspectRatio {
        case .ratio4x3:
            return image
        case .ratio1x1:
            targetRatio = 1.0
        case .ratio16x9:
            targetRatio = 16.0 / 9.0
        }
        
        var cropRect: CGRect
        
        if isRotated {
            if targetRatio > cameraRatio {
                let newDisplayedWidth = cgWidth / targetRatio
                let newCgHeight = newDisplayedWidth
                let yOffset = (cgHeight - newCgHeight) / 2
                cropRect = CGRect(x: 0, y: yOffset, width: cgWidth, height: newCgHeight)
            } else {
                let newDisplayedHeight = cgHeight * targetRatio
                let newCgWidth = newDisplayedHeight
                let xOffset = (cgWidth - newCgWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: newCgWidth, height: cgHeight)
            }
        } else {
            if targetRatio > cameraRatio {
                let newWidth = cgHeight / targetRatio
                let xOffset = (cgWidth - newWidth) / 2
                cropRect = CGRect(x: xOffset, y: 0, width: newWidth, height: cgHeight)
            } else {
                let newHeight = cgWidth * targetRatio
                let yOffset = (cgHeight - newHeight) / 2
                cropRect = CGRect(x: 0, y: yOffset, width: cgWidth, height: newHeight)
            }
        }
        
        guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return nil }
        
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func savePhotoToLibrary(captureResult: CaptureResult) {
        print("📸 Attempting to save photo, data size: \(captureResult.imageData.count) bytes, isLivePhoto: \(captureResult.isLivePhoto)")
        
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        print("📸 Photo library status: \(status.rawValue)")
        
        switch status {
        case .authorized, .limited:
            print("📸 Permission granted, saving...")
            performSave(captureResult: captureResult)
        case .notDetermined:
            print("📸 Permission not determined, requesting...")
            showSaveStatus(.saving)
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
                print("📸 Permission response: \(newStatus.rawValue)")
                DispatchQueue.main.async {
                    self.photoLibraryStatus = newStatus
                    if newStatus == .authorized || newStatus == .limited {
                        self.performSave(captureResult: captureResult)
                    } else {
                        self.showSaveStatus(.error("Photo access denied"))
                        if let movieURL = captureResult.livePhotoMovieURL {
                            try? FileManager.default.removeItem(at: movieURL)
                        }
                    }
                }
            }
        case .denied, .restricted:
            print("📸 Permission denied")
            showSaveStatus(.error("Enable Photos access in Settings"))
            if let movieURL = captureResult.livePhotoMovieURL {
                try? FileManager.default.removeItem(at: movieURL)
            }
        @unknown default:
            print("📸 Unknown permission status")
            showSaveStatus(.error("Unknown error"))
            if let movieURL = captureResult.livePhotoMovieURL {
                try? FileManager.default.removeItem(at: movieURL)
            }
        }
    }
    
    private func performSave(captureResult: CaptureResult) {
        print("📸 performSave called, isLivePhoto: \(captureResult.isLivePhoto)")
        showSaveStatus(.saving)
        
        PHPhotoLibrary.shared().performChanges {
            print("📸 Creating asset...")
            let creationRequest = PHAssetCreationRequest.forAsset()
            
            let photoOptions = PHAssetResourceCreationOptions()
            photoOptions.shouldMoveFile = false
            creationRequest.addResource(with: .photo, data: captureResult.imageData, options: photoOptions)
            
            if let movieURL = captureResult.livePhotoMovieURL {
                print("📸 Adding Live Photo paired video from: \(movieURL)")
                let videoOptions = PHAssetResourceCreationOptions()
                videoOptions.shouldMoveFile = true
                creationRequest.addResource(with: .pairedVideo, fileURL: movieURL, options: videoOptions)
            }
        } completionHandler: { success, error in
            print("📸 Save result - success: \(success), error: \(error?.localizedDescription ?? "none")")
            
            if let movieURL = captureResult.livePhotoMovieURL {
                try? FileManager.default.removeItem(at: movieURL)
            }
            
            DispatchQueue.main.async {
                if success {
                    if captureResult.isLivePhoto {
                        self.showSaveStatus(.saved)
                        print("📸 Live Photo saved successfully!")
                    } else {
                        self.showSaveStatus(.saved)
                    }
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
