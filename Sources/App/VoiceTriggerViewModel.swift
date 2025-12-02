import AVFoundation
import AVFAudio
import Combine
import Foundation
import Speech

enum VoicePermissionStatus: Equatable {
    case unknown
    case notDetermined
    case granted
    case denied
    case restricted

    var isGranted: Bool {
        self == .granted
    }

    var requiresSystemSettings: Bool {
        switch self {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    var isRequestable: Bool {
        self == .notDetermined
    }
}

extension VoicePermissionStatus {
    init(speechStatus: SFSpeechRecognizerAuthorizationStatus) {
        switch speechStatus {
        case .authorized:
            self = .granted
        case .denied:
            self = .denied
        case .restricted:
            self = .restricted
        case .notDetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }

    init(recordPermission: AVAudioSession.RecordPermission) {
        switch recordPermission {
        case .granted:
            self = .granted
        case .denied:
            self = .denied
        case .undetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }

    @available(iOS 17.0, *)
    init(appRecordPermission: AVAudioApplication.recordPermission) {
        switch appRecordPermission {
        case .granted:
            self = .granted
        case .denied:
            self = .denied
        case .undetermined:
            self = .notDetermined
        @unknown default:
            self = .unknown
        }
    }
}

final class VoiceTriggerViewModel: ObservableObject {
    @Published var triggerPhrase: String
    @Published var statusMessage: String = "Idle"
    @Published var isListening = false
    @Published var lastTriggerDescription: String?
    @Published var lastTranscription: String?
    @Published var isTestingMode = false  // When true, triggers won't capture photos
    @Published var errorMessage: String?
    @Published private(set) var speechPermissionStatus: VoicePermissionStatus = .unknown
    @Published private(set) var microphonePermissionStatus: VoicePermissionStatus = .unknown

    private let service: VoiceTriggerService
    private let defaultTriggerPhrase: String
    private var cancellables = Set<AnyCancellable>()
    private let workerQueue = DispatchQueue(label: "VoiceTriggerViewModel.Worker")
    private var pendingAutoStart = false
    private var isRequestingSpeechPermission = false
    private var isRequestingMicrophonePermission = false

    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()

    var canStartListening: Bool {
        speechPermissionStatus.isGranted && microphonePermissionStatus.isGranted
    }

    var callToActionCopy: String {
        if canStartListening {
            return "Say \"\(triggerPhrase)\" to initiate the countdown once the listener is active."
        } else {
            return "Grant speech recognition and microphone permissions to enable voice triggers."
        }
    }

    init(service: VoiceTriggerService? = nil, defaultTriggerPhrase: String = "camera me") {
        self.defaultTriggerPhrase = defaultTriggerPhrase
        self.triggerPhrase = defaultTriggerPhrase

        let resolvedService: VoiceTriggerService
        var initializationError: String?

        if let service {
            resolvedService = service
        } else if let speechService = try? SpeechVoiceTriggerService(initialTriggerPhrase: defaultTriggerPhrase) {
            resolvedService = speechService
        } else {
            resolvedService = DisabledVoiceTriggerService()
            initializationError = "Speech recognition is unavailable on this device."
        }

        self.service = resolvedService
        self.errorMessage = initializationError

        refreshPermissions()
        bindTriggerStream()
        bindServiceEvents()
        bindTranscriptionStream()
        propagateTriggerPhraseChange()
    }

    deinit {
        service.stopListening()
    }

    func startListening() {
        guard !isListening else { return }

        guard canStartListening else {
            pendingAutoStart = true
            DispatchQueue.main.async {
                self.errorMessage = "Microphone and speech permissions are required before listening can start."
                self.updateStatusForMissingPermissions()
            }
            requestPermissionsIfNeeded()
            return
        }

        pendingAutoStart = false

        DispatchQueue.main.async {
            self.statusMessage = "Initializing listener…"
            self.errorMessage = nil
        }

        propagateTriggerPhraseChange()

        workerQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.service.startListening()
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = self.userMessage(for: error)
                    self.statusMessage = "Listener inactive"
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        pendingAutoStart = false

        workerQueue.async { [weak self] in
            guard let self else { return }
            self.service.stopListening()
        }
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }

    func handleTriggerPhraseChange() {
        propagateTriggerPhraseChange()
    }

    func refreshPermissions() {
        speechPermissionStatus = Self.currentSpeechPermissionStatus()
        microphonePermissionStatus = Self.currentMicrophonePermissionStatus()
        handlePermissionStateChange()
    }

    func requestSpeechPermission() {
        guard speechPermissionStatus.isRequestable, !isRequestingSpeechPermission else { return }
        isRequestingSpeechPermission = true

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRequestingSpeechPermission = false
                self.speechPermissionStatus = VoicePermissionStatus(speechStatus: status)
                self.handlePermissionStateChange()
            }
        }
    }

    func requestMicrophonePermission() {
        guard microphonePermissionStatus.isRequestable, !isRequestingMicrophonePermission else { return }
        isRequestingMicrophonePermission = true

        let completion: (Bool) -> Void = { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRequestingMicrophonePermission = false
                self.microphonePermissionStatus = granted ? .granted : .denied
                self.handlePermissionStateChange()
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
}

// MARK: - Private helpers

private extension VoiceTriggerViewModel {
    var listeningStatusMessage: String {
        "Listening for \"\(triggerPhrase)\""
    }

    var permissionStatusMessage: String {
        switch (speechPermissionStatus.isGranted, microphonePermissionStatus.isGranted) {
        case (true, true):
            return listeningStatusMessage
        case (false, true):
            return "Enable speech recognition permission to start listening."
        case (true, false):
            return "Enable microphone permission to start listening."
        default:
            return "Enable speech recognition and microphone permissions to start listening."
        }
    }

    static func currentSpeechPermissionStatus() -> VoicePermissionStatus {
        VoicePermissionStatus(speechStatus: SFSpeechRecognizer.authorizationStatus())
    }

    static func currentMicrophonePermissionStatus() -> VoicePermissionStatus {
        if #available(iOS 17, *) {
            return VoicePermissionStatus(appRecordPermission: AVAudioApplication.shared.recordPermission)
        } else {
            return VoicePermissionStatus(recordPermission: AVAudioSession.sharedInstance().recordPermission)
        }
    }

    func requestPermissionsIfNeeded() {
        if speechPermissionStatus.isRequestable {
            requestSpeechPermission()
        }
        if microphonePermissionStatus.isRequestable {
            requestMicrophonePermission()
        }
    }

    func handlePermissionStateChange() {
        if pendingAutoStart, canStartListening, !isListening {
            pendingAutoStart = false
            startListening()
            return
        }

        if !canStartListening && !isListening {
            statusMessage = permissionStatusMessage
        } else if isListening {
            statusMessage = listeningStatusMessage
        }
    }

    func updateStatusForMissingPermissions() {
        statusMessage = permissionStatusMessage
    }

    func bindTriggerStream() {
        service.triggerPublisher
            .receiveOnMain()
            .sink { [weak self] in
                self?.handleTriggerEvent()
            }
            .store(in: &cancellables)
    }

    func bindServiceEvents() {
        service.eventPublisher
            .receiveOnMain()
            .sink { [weak self] event in
                self?.handleServiceEvent(event)
            }
            .store(in: &cancellables)
    }
    
    func bindTranscriptionStream() {
        service.transcriptionPublisher
            .receiveOnMain()
            .sink { [weak self] transcription in
                self?.lastTranscription = transcription
            }
            .store(in: &cancellables)
    }

    func handleTriggerEvent() {
        let timestamp = dateFormatter.string(from: Date())
        lastTriggerDescription = timestamp
        statusMessage = "Trigger heard at \(timestamp)"

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self, self.isListening else { return }
            self.statusMessage = self.listeningStatusMessage
        }
    }

    func handleServiceEvent(_ event: VoiceTriggerServiceEvent) {
        switch event {
        case .started:
            isListening = true
            errorMessage = nil
            statusMessage = listeningStatusMessage
        case .stopped:
            isListening = false
            statusMessage = "Listener paused"
        case .failure(let error):
            // Don't set isListening = false on transient errors like "No speech detected"
            // The service auto-restarts and will send .started again
            // Only log for debugging, don't update UI state to avoid flickering
            #if DEBUG
            print("Voice trigger transient error (will auto-restart): \(error.localizedDescription)")
            #endif
            // Only show error message if it's not a common transient error
            let errorDesc = error.localizedDescription.lowercased()
            if !errorDesc.contains("no speech") && !errorDesc.contains("speech detected") {
                errorMessage = userMessage(for: error)
                statusMessage = "Reconnecting..."
            }
        }
    }

    func propagateTriggerPhraseChange() {
        let trimmed = triggerPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.isEmpty ? defaultTriggerPhrase : trimmed

        if normalized != triggerPhrase {
            triggerPhrase = normalized
            return
        }

        service.updateTriggerPhrase(normalized)

        if isListening {
            statusMessage = listeningStatusMessage
        }
    }

    func userMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }

        let description = error.localizedDescription
        return description.isEmpty ? "Something went wrong while starting the listener." : description
    }
}
