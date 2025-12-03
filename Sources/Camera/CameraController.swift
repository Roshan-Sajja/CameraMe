import AVFoundation
import Combine
import UIKit

// MARK: - Capture Result

struct CaptureResult {
    let imageData: Data
}

// MARK: - Camera Enums

enum CameraPosition: String {
    case front = "front"
    case back = "back"
    
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .front: return .front
        case .back: return .back
        }
    }

        mutating func toggle() {
            self = self == .front ? .back : .front
        }
    }

enum CameraLens: String, CaseIterable {
    case ultraWide = "0.5x"
    case wide = "1x"
    case telephoto2x = "2x"
    case telephoto3x = "3x"
    case telephoto5x = "5x"
    
    var systemZoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 0.5
        case .wide: return 1.0
        case .telephoto2x: return 2.0
        case .telephoto3x: return 3.0
        case .telephoto5x: return 5.0
        }
    }
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto2x, .telephoto3x, .telephoto5x: return .builtInTelephotoCamera
        }
    }
}

enum FlashMode: String, CaseIterable {
    case off = "Off"
    case on = "On"
    case auto = "Auto"
    
    var avFlashMode: AVCaptureDevice.FlashMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.badge.automatic.fill"
        }
    }
}

enum AspectRatio: String, CaseIterable {
    case ratio4x3 = "4:3"
    case ratio1x1 = "1:1"
    case ratio16x9 = "16:9"
    
    var multiplier: CGFloat {
        switch self {
        case .ratio4x3: return 4.0 / 3.0
        case .ratio1x1: return 1.0
        case .ratio16x9: return 16.0 / 9.0
        }
    }
}

enum TimerDuration: Int, CaseIterable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10
    
    var displayName: String {
        switch self {
        case .off: return "Off"
        case .three: return "3s"
        case .five: return "5s"
        case .ten: return "10s"
        }
    }
    
    var icon: String {
        switch self {
        case .off: return "timer"
        default: return "timer"
        }
    }
}

// MARK: - Camera Controller

final class CameraController: NSObject, ObservableObject {
    // MARK: - UserDefaults Keys
    private enum DefaultsKey {
        static let cameraPosition = "camera_position"
        static let flashMode = "flash_mode"
        static let aspectRatio = "aspect_ratio"
        static let timerDuration = "timer_duration"
        static let showGridLines = "show_grid_lines"
    }
    
    // MARK: - Published Properties

    @Published private(set) var isSessionRunning = false
    @Published private(set) var isCaptureReady = false
    @Published var cameraPosition: CameraPosition = .back
    @Published var currentLens: CameraLens = .wide
    @Published var flashMode: FlashMode = .auto
    @Published var aspectRatio: AspectRatio = .ratio4x3
    @Published var timerDuration: TimerDuration = .off
    @Published var zoomFactor: CGFloat = 1.0
    @Published var availableLenses: [CameraLens] = [.wide]
    @Published var minZoom: CGFloat = 1.0
    @Published var maxZoom: CGFloat = 10.0
    @Published private(set) var isTimerRunning = false
    @Published private(set) var timerCountdown: Int = 0
    @Published var showGridLines = false
    
    // MARK: - Private Properties

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraController.SessionQueue")
    private var currentInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()
    private var pendingPhotoCompletion: ((Result<CaptureResult, Error>) -> Void)?
    private var timerWorkItem: DispatchWorkItem?
    private var currentVideoOrientation: AVCaptureVideoOrientation = .portrait
    private var didPlayShutterSound = false
    
    let previewLayer: AVCaptureVideoPreviewLayer
    
    // MARK: - Computed Properties
    
    var hasFlash: Bool {
        currentInput?.device.hasFlash ?? false
    }
    
    // MARK: - Initialization

    override init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
        // Fill the visible region and avoid side letterboxing when aspect ratios change
        previewLayer.videoGravity = .resizeAspectFill
        
        super.init()
        
        // Load saved settings from UserDefaults
        loadSavedSettings()
        
        discoverAvailableLenses()
    }
    
    private func loadSavedSettings() {
        let defaults = UserDefaults.standard
        
        // Load camera position
        if let positionRaw = defaults.string(forKey: DefaultsKey.cameraPosition),
           let position = CameraPosition(rawValue: positionRaw) {
            cameraPosition = position
        }
        
        // Load flash mode
        if let flashRaw = defaults.string(forKey: DefaultsKey.flashMode),
           let flash = FlashMode(rawValue: flashRaw) {
            flashMode = flash
        }
        
        // Load aspect ratio
        if let ratioRaw = defaults.string(forKey: DefaultsKey.aspectRatio),
           let ratio = AspectRatio(rawValue: ratioRaw) {
            aspectRatio = ratio
        }
        
        // Load timer duration
        let timerRaw = defaults.integer(forKey: DefaultsKey.timerDuration)
        if let timer = TimerDuration(rawValue: timerRaw) {
            timerDuration = timer
        }
        
        // Load grid lines
        showGridLines = defaults.bool(forKey: DefaultsKey.showGridLines)
    }
    
    // MARK: - Save Defaults (for Settings view)
    
    func saveDefaultCameraPosition(_ position: CameraPosition) {
        UserDefaults.standard.set(position.rawValue, forKey: DefaultsKey.cameraPosition)
    }
    
    func saveDefaultFlashMode(_ mode: FlashMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: DefaultsKey.flashMode)
    }
    
    func saveDefaultAspectRatio(_ ratio: AspectRatio) {
        UserDefaults.standard.set(ratio.rawValue, forKey: DefaultsKey.aspectRatio)
    }
    
    func saveDefaultTimerDuration(_ duration: TimerDuration) {
        UserDefaults.standard.set(duration.rawValue, forKey: DefaultsKey.timerDuration)
    }
    
    func saveDefaultShowGridLines(_ show: Bool) {
        UserDefaults.standard.set(show, forKey: DefaultsKey.showGridLines)
    }

    // MARK: - Public Methods

    func startSession() {
        guard !session.isRunning else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.currentInput == nil {
                self.configureSessionOnQueue()
            }
            
            self.session.startRunning()
            self.applyCurrentOrientationLocked()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                self.discoverAvailableLenses()
                self.updateZoomLimits()
            }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }
    
    func cycleAspectRatio() {
        let allRatios = AspectRatio.allCases
        if let currentIndex = allRatios.firstIndex(of: aspectRatio) {
            let nextIndex = (currentIndex + 1) % allRatios.count
            aspectRatio = allRatios[nextIndex]
        }
    }
    
    func cycleFlashMode() {
        let allModes = FlashMode.allCases
        if let currentIndex = allModes.firstIndex(of: flashMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            flashMode = allModes[nextIndex]
        }
    }
    
    func cycleTimerDuration() {
        let allDurations = TimerDuration.allCases
        if let currentIndex = allDurations.firstIndex(of: timerDuration) {
            let nextIndex = (currentIndex + 1) % allDurations.count
            timerDuration = allDurations[nextIndex]
        }
    }

    func toggleCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            let newPosition: CameraPosition = self.cameraPosition == .back ? .front : .back
            
            guard let newDevice = self.device(for: newPosition, lens: .wide),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            }
            
            self.session.commitConfiguration()
            self.applyCurrentOrientationLocked()
            
            DispatchQueue.main.async {
                self.cameraPosition = newPosition
                self.currentLens = .wide
                self.zoomFactor = 1.0
                self.discoverAvailableLenses()
                self.updateZoomLimits()
            }
        }
    }
    
    func switchLens(_ lens: CameraLens) {
        guard availableLenses.contains(lens) else { return }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            guard let device = self.device(for: self.cameraPosition, lens: lens),
                  let newInput = try? AVCaptureDeviceInput(device: device) else {
                // Fallback to wide angle
                if let wideDevice = self.device(for: self.cameraPosition, lens: .wide),
                   let wideInput = try? AVCaptureDeviceInput(device: wideDevice) {
                    if self.session.canAddInput(wideInput) {
                        self.session.addInput(wideInput)
                        self.currentInput = wideInput
                    }
                }
                self.session.commitConfiguration()
                return
            }
            
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.currentInput = newInput
            }
            
            self.session.commitConfiguration()
            
            DispatchQueue.main.async {
                self.currentLens = lens
                self.zoomFactor = lens.systemZoomFactor
                self.updateZoomLimits()
            }
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = currentInput?.device else { return }
        
        let clampedFactor = min(max(factor, minZoom), maxZoom)
        
        sessionQueue.async { [weak self] in
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedFactor
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self?.zoomFactor = clampedFactor
                }
            } catch {
                print("🎥 Failed to set zoom: \(error)")
            }
        }
    }

    func capturePhoto(completion: @escaping (Result<CaptureResult, Error>) -> Void) {
        print("🎥 capturePhoto called, isCaptureReady: \(isCaptureReady), isRunning: \(session.isRunning)")
        
        guard isCaptureReady else {
            print("🎥 Camera not ready!")
            completion(.failure(CameraError.notReady))
            return
        }
        
        // Handle timer
        if timerDuration != .off {
            startTimer(completion: completion)
            return
        }
        
        performCapture(completion: completion)
    }

    func updateVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentVideoOrientation = orientation
            self.applyCurrentOrientationLocked()
        }
    }
    
    func cancelTimer() {
        timerWorkItem?.cancel()
        timerWorkItem = nil
        DispatchQueue.main.async {
            self.isTimerRunning = false
            self.timerCountdown = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func startTimer(completion: @escaping (Result<CaptureResult, Error>) -> Void) {
        let duration = timerDuration.rawValue
        
        DispatchQueue.main.async {
            self.isTimerRunning = true
            self.timerCountdown = duration
            SoundEffectsPlayer.shared.playTimerTick()
        }
        
        func tick(_ remaining: Int) {
            if remaining <= 0 {
                DispatchQueue.main.async {
                    self.isTimerRunning = false
                    self.timerCountdown = 0
                }
                self.performCapture(completion: completion)
                return
            }
            
            DispatchQueue.main.async {
                self.timerCountdown = remaining
                SoundEffectsPlayer.shared.playTimerTick()
            }
            
            let workItem = DispatchWorkItem { [weak self] in
                tick(remaining - 1)
            }
            self.timerWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
        }
        
        tick(duration)
    }
    
    private func performCapture(completion: @escaping (Result<CaptureResult, Error>) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.pendingPhotoCompletion = completion
            self.didPlayShutterSound = false
            
            if let connection = self.photoOutput.connection(with: .video),
               connection.isVideoOrientationSupported {
                connection.videoOrientation = self.currentVideoOrientation
            }
            
            var settings = AVCapturePhotoSettings()
            
            if self.photoOutput.availablePhotoCodecTypes.contains(.hevc) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
            }
            
            if #available(iOS 16.0, *) {
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
            }
            
            if let device = self.currentInput?.device, device.hasFlash {
                settings.flashMode = self.flashMode.avFlashMode
            }
            
            print("🎥 Calling photoOutput.capturePhoto with flash: \(self.flashMode)")
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
    private func configureSessionOnQueue() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        if let currentInput = currentInput {
            session.removeInput(currentInput)
        }
        
        guard let videoDevice = device(for: cameraPosition, lens: currentLens) ?? device(for: cameraPosition, lens: .wide),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(videoInput) {
            session.addInput(videoInput)
            currentInput = videoInput
        }
        
        // Configure device frame rate to match display
        configureDeviceFrameRate(videoDevice)
        
        if session.outputs.isEmpty {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
            }
        }
        
        session.commitConfiguration()
        applyCurrentOrientationLocked()
        
        DispatchQueue.main.async { [weak self] in
            self?.isCaptureReady = true
            self?.updateZoomLimits()
        }
    }
    
    private func configureDeviceFrameRate(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            
            // Get the display's maximum refresh rate
            let screenMaxFrameRate = UIScreen.main.maximumFramesPerSecond // 60 or 120 for ProMotion
            
            // Find the best format that supports the highest frame rate up to screen refresh
            // Camera typically supports 30fps or 60fps, some support higher
            var bestFrameRate: Double = 30.0
            
            if let activeFormat = device.activeFormat.videoSupportedFrameRateRanges.first {
                // Use the maximum frame rate supported by the current format
                // But cap it at the screen's refresh rate (no point going higher)
                bestFrameRate = min(activeFormat.maxFrameRate, Double(screenMaxFrameRate))
                
                // For smoother preview, prefer 60fps if available, or max if higher
                if activeFormat.maxFrameRate >= 60 {
                    bestFrameRate = min(60.0, Double(screenMaxFrameRate))
                }
            }
            
            // Set frame rate
            device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: CMTimeScale(bestFrameRate))
            device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: CMTimeScale(bestFrameRate))
            
            device.unlockForConfiguration()
            print("🎥 Configured device frame rate: \(bestFrameRate) fps (screen max: \(screenMaxFrameRate) Hz)")
        } catch {
            print("🎥 Failed to configure device frame rate: \(error)")
        }
    }

    private func applyCurrentOrientationLocked() {
        let orientation = currentVideoOrientation
        
        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoOrientationSupported {
            photoConnection.videoOrientation = orientation
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let previewConnection = self.previewLayer.connection,
               previewConnection.isVideoOrientationSupported {
                previewConnection.videoOrientation = .portrait
            }
        }
    }
    
    private func device(for position: CameraPosition, lens: CameraLens) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [lens.deviceType],
            mediaType: .video,
            position: position.avPosition
        )
        return discoverySession.devices.first
    }
    
    private func discoverAvailableLenses() {
        // Use the main back/front camera to read its zoom switch-over factors to determine actual lenses.
        let baseDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: cameraPosition.avPosition)
        
        var lenses = Set<CameraLens>()
        if baseDevice != nil {
            lenses.insert(.wide)
        }
        
        // Ultra-wide availability
        let ultraSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInUltraWideCamera],
            mediaType: .video,
            position: cameraPosition.avPosition
        )
        if ultraSession.devices.contains(where: { $0.position == cameraPosition.avPosition }) {
            lenses.insert(.ultraWide)
        }
        
        // Telephoto options via switch-over zoom factors (more reliable than min/max zoom alone).
        if let factors = baseDevice?.virtualDeviceSwitchOverVideoZoomFactors {
            for factor in factors {
                switch factor.doubleValue {
                case ..<1.0:
                    lenses.insert(.ultraWide)
                case 1.5..<2.6:
                    lenses.insert(.telephoto2x)
                case 2.6..<4.5:
                    lenses.insert(.telephoto3x)
                default:
                    lenses.insert(.telephoto5x)
                }
            }
        } else {
            // Fallback: inspect telephoto devices directly.
            let teleDiscovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInTelephotoCamera],
                mediaType: .video,
                position: cameraPosition.avPosition
            )
            for device in teleDiscovery.devices where device.position == cameraPosition.avPosition {
                let minZoom = device.minAvailableVideoZoomFactor
                if minZoom >= 4.5 {
                    lenses.insert(.telephoto5x)
                } else if minZoom >= 2.5 {
                    lenses.insert(.telephoto3x)
                } else {
                    lenses.insert(.telephoto2x)
                }
            }
        }
        
        if lenses.isEmpty {
            lenses.insert(.wide)
        }
        
        let sorted = lenses.sorted { $0.systemZoomFactor < $1.systemZoomFactor }
        DispatchQueue.main.async { [weak self] in
            self?.availableLenses = sorted
        }
    }
    
    private func updateZoomLimits() {
        guard let device = currentInput?.device else { return }
        
        DispatchQueue.main.async {
            self.minZoom = device.minAvailableVideoZoomFactor
            self.maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0) // Cap at 10x
        }
    }
    
}

// MARK: - Errors

extension CameraController {
    enum CameraError: LocalizedError {
        case notReady
        case captureFailed
        case noImageData
        
        var errorDescription: String? {
            switch self {
            case .notReady:
                return "Camera is not ready to capture photos."
            case .captureFailed:
                return "Failed to capture photo."
            case .noImageData:
                return "No image data was captured."
            }
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("🎥 didFinishProcessingPhoto called")
        
        if let error = error {
            print("🎥 Photo capture error: \(error.localizedDescription)")
            let completion = pendingPhotoCompletion
            pendingPhotoCompletion = nil
            DispatchQueue.main.async {
                completion?(.failure(error))
            }
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("🎥 No image data!")
            let completion = pendingPhotoCompletion
            pendingPhotoCompletion = nil
            DispatchQueue.main.async {
                completion?(.failure(CameraError.noImageData))
            }
            return
        }
        
        print("🎥 Photo captured successfully, size: \(imageData.count) bytes")
        
        if !didPlayShutterSound {
            let hasDeviceFlash = currentInput?.device.hasFlash ?? false
            let flashActive = hasDeviceFlash && (flashMode == .on || flashMode == .auto)
            let isFrontCamera = currentInput?.device.position == .front
            
            if !flashActive && !isFrontCamera {
                DispatchQueue.main.async {
                    SoundEffectsPlayer.shared.playShutter()
                }
            }
            didPlayShutterSound = true
        }
        
        let completion = pendingPhotoCompletion
        pendingPhotoCompletion = nil
        DispatchQueue.main.async {
            let result = CaptureResult(imageData: imageData)
            completion?(.success(result))
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        print("🎥 didFinishCaptureFor called")
        
        if let error = error {
            print("🎥 Capture finished with error: \(error.localizedDescription)")
        }
        
        didPlayShutterSound = false
    }
}
