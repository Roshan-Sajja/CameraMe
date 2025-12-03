import Combine
import Foundation

final class VoiceTriggerViewModel: ObservableObject {
    @Published var triggerPhrase: String {
        didSet {
            UserDefaults.standard.set(triggerPhrase, forKey: "trigger_phrase")
        }
    }
    @Published var statusMessage: String = "Idle"
    @Published var isListening = false
    @Published var lastTriggerDescription: String?
    @Published var lastTranscription: String?
    @Published var isTestingMode = false
    @Published var errorMessage: String?
    @Published private(set) var speechPermissionStatus: VoicePermissionStatus = .unknown
    @Published private(set) var microphonePermissionStatus: VoicePermissionStatus = .unknown
    @Published var audioInputs: [AudioInputSource] = []
    @Published var selectedAudioInputID: String?

    private let service: VoiceTriggerService
    private let defaultTriggerPhrase: String
    private var cancellables = Set<AnyCancellable>()
    private let workerQueue = DispatchQueue(label: "VoiceTriggerViewModel.Worker")
    private var pendingAutoStart = false
    private var autoStartRetryCount = 0
    private let maxAutoStartRetries = 3
    private var autoStartRetryWorkItem: DispatchWorkItem?

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
        
        let savedPhrase = UserDefaults.standard.string(forKey: "trigger_phrase")
        let initialPhrase = savedPhrase ?? defaultTriggerPhrase
        self.triggerPhrase = initialPhrase

        let resolvedService: VoiceTriggerService
        var initializationError: String?

        if let service {
            resolvedService = service
        } else if let speechService = try? SpeechVoiceTriggerService(initialTriggerPhrase: initialPhrase) {
            resolvedService = speechService
        } else {
            resolvedService = DisabledVoiceTriggerService()
            initializationError = "Speech recognition is unavailable on this device."
        }

        self.service = resolvedService
        self.errorMessage = initializationError

        bindTriggerStream()
        bindServiceEvents()
        bindTranscriptionStream()
        bindPermissionStream()
        bindAudioRouteStream()
        refreshPermissions()
        propagateTriggerPhraseChange()
    }

    deinit {
        service.stopListening()
    }

    func startListening(force: Bool = false) {
        guard force || !isListening else {
            return
        }

        service.refreshPermissions()

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
                self.autoStartRetryWorkItem?.cancel()
                DispatchQueue.main.async {
                    self.errorMessage = self.userMessage(for: error)
                    self.statusMessage = "Listener inactive"
                }
            }
        }

        scheduleAutoStartRetry()
    }

    func stopListening() {
        guard isListening else { return }
        pendingAutoStart = false
        autoStartRetryWorkItem?.cancel()
        autoStartRetryCount = 0

        workerQueue.async { [weak self] in
            guard let self else { return }
            self.service.stopListening()
        }
    }

    func toggleListening() {
        isListening ? stopListening() : startListening()
    }
    func restartListening() {
        // Allow stop to complete before starting again.
        stopListening()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.startListening(force: true)
        }
    }

    func handleTriggerPhraseChange() {
        propagateTriggerPhraseChange()
    }

    func refreshPermissions() {
        let micStatus = VoicePermissionReader.currentMicrophonePermissionStatus()
        let speechStatus = VoicePermissionReader.currentSpeechPermissionStatus()

        microphonePermissionStatus = micStatus
        speechPermissionStatus = speechStatus
        handlePermissionStateChange()
        service.refreshPermissions()
    }

    func requestPermissionsIfNeeded() {
        service.requestPermissionsIfNeeded()
    }

    func refreshAudioInputs() {
        service.selectPreferredInput(id: selectedAudioInputID)
    }

    func selectAudioInput(id: String?) {
        selectedAudioInputID = id
        service.selectPreferredInput(id: id)
    }
}

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

    func bindPermissionStream() {
        service.permissionPublisher
            .receiveOnMain()
            .sink { [weak self] snapshot in
                guard let self else { return }
                self.microphonePermissionStatus = snapshot.microphone
                self.speechPermissionStatus = snapshot.speech
                self.handlePermissionStateChange()
            }
            .store(in: &cancellables)
    }

    func bindAudioRouteStream() {
        service.audioRoutePublisher
            .receiveOnMain()
            .sink { [weak self] inputs in
                guard let self else { return }
                self.audioInputs = inputs

                if let selectedAudioInputID,
                   inputs.contains(where: { $0.id == selectedAudioInputID }) {
                    return
                }

                if let activeInput = inputs.first(where: { $0.isCurrent }) {
                    self.selectedAudioInputID = activeInput.id
                } else if let first = inputs.first {
                    self.selectedAudioInputID = first.id
                }
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
            autoStartRetryWorkItem?.cancel()
            autoStartRetryCount = 0
        case .stopped:
            isListening = false
            statusMessage = "Listener paused"
        case .failure(let error):
            #if DEBUG
            print("Voice trigger transient error (will auto-restart): \(error.localizedDescription)")
            #endif
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

    func scheduleAutoStartRetry() {
        autoStartRetryWorkItem?.cancel()
        guard autoStartRetryCount < maxAutoStartRetries else { return }

        autoStartRetryCount += 1

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isListening else { return }
            guard self.canStartListening else { return }
            self.startListening()
        }

        autoStartRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
    }
}
