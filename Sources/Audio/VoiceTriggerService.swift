import AVFoundation
import AVFAudio
import Combine
import Foundation
import Speech

enum VoiceTriggerServiceEvent {
    case started
    case stopped
    case failure(Error)
}

protocol VoiceTriggerService {
    var triggerPublisher: AnyPublisher<Void, Never> { get }
    var eventPublisher: AnyPublisher<VoiceTriggerServiceEvent, Never> { get }
    
    var transcriptionPublisher: AnyPublisher<String, Never> { get }

    var permissionPublisher: AnyPublisher<VoicePermissionSnapshot, Never> { get }

    var audioRoutePublisher: AnyPublisher<[AudioInputSource], Never> { get }

    func updateTriggerPhrase(_ phrase: String)

    func startListening() throws

    func stopListening()

    func refreshPermissions()

    func requestPermissionsIfNeeded()

    func selectPreferredInput(id: String?)
}

enum VoiceTriggerServiceError: Error {
    case speechRecognizerUnavailable
    case speechPermissionDenied
    case microphonePermissionDenied
    case simulatorUnsupported
}

extension VoiceTriggerServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available for the selected locale."
        case .speechPermissionDenied:
            return "Speech recognition permission is required to listen for the trigger phrase."
        case .microphonePermissionDenied:
            return "Microphone permission is required so the app can hear you."
        case .simulatorUnsupported:
            return "Speech recognition requires a physical device; it is unavailable in the simulator."
        }
    }
}

final class SpeechVoiceTriggerService: NSObject, VoiceTriggerService, SFSpeechRecognizerDelegate {
    private let subject = PassthroughSubject<Void, Never>()
    private let eventSubject = PassthroughSubject<VoiceTriggerServiceEvent, Never>()
    private let transcriptionSubject = PassthroughSubject<String, Never>()
    private let permissionSubject: CurrentValueSubject<VoicePermissionSnapshot, Never>
    private let audioRouteSubject: CurrentValueSubject<[AudioInputSource], Never>
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer
    private let sessionQueue = DispatchQueue(label: "VoiceTriggerService.SessionQueue")

    private var normalizedTriggerPhrase: String
    private let defaultTriggerPhrase: String
    private var lastTriggerDate: Date?
    private let triggerThrottle: TimeInterval = 2.0
    private var isSessionRunning = false
    private var shouldAttemptRestart = true
    private var lastMatchedCharacterCount = 0
    private var routeChangeObserver: Any?
    private var isRestarting = false
    private var preferredInputID: String?
    private var isRequestingSpeechPermission = false
    private var isRequestingMicrophonePermission = false

    var triggerPublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var eventPublisher: AnyPublisher<VoiceTriggerServiceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    var transcriptionPublisher: AnyPublisher<String, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }

    var permissionPublisher: AnyPublisher<VoicePermissionSnapshot, Never> {
        permissionSubject.eraseToAnyPublisher()
    }

    var audioRoutePublisher: AnyPublisher<[AudioInputSource], Never> {
        audioRouteSubject.eraseToAnyPublisher()
    }

    init(locale: Locale = Locale(identifier: "en-US"), initialTriggerPhrase: String = "camera me") throws {
#if targetEnvironment(simulator)
        throw VoiceTriggerServiceError.simulatorUnsupported
#endif
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw VoiceTriggerServiceError.speechRecognizerUnavailable
        }

        let initialPermissions = VoicePermissionSnapshot(
            microphone: VoicePermissionReader.currentMicrophonePermissionStatus(),
            speech: VoicePermissionReader.currentSpeechPermissionStatus()
        )

        permissionSubject = CurrentValueSubject(initialPermissions)
        audioRouteSubject = CurrentValueSubject([])
        speechRecognizer = recognizer
        defaultTriggerPhrase = initialTriggerPhrase
        normalizedTriggerPhrase = SpeechVoiceTriggerService.normalizeTrigger(initialTriggerPhrase)

        super.init()

        speechRecognizer.delegate = self
        observeRouteChanges()
        refreshAudioRoute()
    }
    
    deinit {
        if let routeChangeObserver {
            NotificationCenter.default.removeObserver(routeChangeObserver)
        }
    }

    func updateTriggerPhrase(_ phrase: String) {
        let normalized = SpeechVoiceTriggerService.normalizeTrigger(phrase)
        normalizedTriggerPhrase = normalized.isEmpty ? SpeechVoiceTriggerService.normalizeTrigger(defaultTriggerPhrase) : normalized
        resetTranscriptionMatchProgress()
    }

    func startListening() throws {
        guard !isSessionRunning else { return }
        shouldAttemptRestart = true
        resetTranscriptionMatchProgress()
        try ensurePermissions()

        var startError: Error?
        sessionQueue.sync {
            do {
                try self.configureAudioSession()
                self.refreshAudioRoute()
                try self.startRecognitionLocked(resetAudio: true)
                self.isSessionRunning = true
            } catch {
                startError = error
                self.isSessionRunning = false
            }
        }

        if let startError {
            eventSubject.send(.failure(startError))
            throw startError
        }

        eventSubject.send(.started)
    }

    func stopListening() {
        shouldAttemptRestart = false
        resetTranscriptionMatchProgress()

        sessionQueue.sync {
            guard isSessionRunning else { return }

            recognitionTask?.cancel()
            recognitionTask = nil
            recognitionRequest?.endAudio()
            recognitionRequest = nil

            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)

            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            isSessionRunning = false
        }

        eventSubject.send(.stopped)
    }

    func refreshPermissions() {
        let snapshot = VoicePermissionSnapshot(
            microphone: VoicePermissionReader.currentMicrophonePermissionStatus(),
            speech: VoicePermissionReader.currentSpeechPermissionStatus()
        )
        permissionSubject.send(snapshot)
    }

    func requestPermissionsIfNeeded() {
        refreshPermissions()
        let snapshot = permissionSubject.value

        if snapshot.speech.isRequestable && !isRequestingSpeechPermission {
            isRequestingSpeechPermission = true
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingSpeechPermission = false
                    let currentMic = self.permissionSubject.value.microphone
                    self.permissionSubject.send(
                        VoicePermissionSnapshot(
                            microphone: currentMic,
                            speech: VoicePermissionStatus(speechStatus: status)
                        )
                    )
                }
            }
        }

        if snapshot.microphone.isRequestable && !isRequestingMicrophonePermission {
            isRequestingMicrophonePermission = true

            let completion: (Bool) -> Void = { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingMicrophonePermission = false
                    let currentSpeech = self.permissionSubject.value.speech
                    self.permissionSubject.send(
                        VoicePermissionSnapshot(
                            microphone: granted ? .granted : .denied,
                            speech: currentSpeech
                        )
                    )
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

    func selectPreferredInput(id: String?) {
        preferredInputID = id
        
        // Apply the input change immediately if session is running
        if isSessionRunning {
            sessionQueue.async { [weak self] in
                guard let self, !self.isRestarting else { return }
                self.restartRecognition(resetAudio: true)
            }
        }
        
        refreshAudioRoute()
    }
}

struct DisabledVoiceTriggerService: VoiceTriggerService {
    var triggerPublisher: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

    var eventPublisher: AnyPublisher<VoiceTriggerServiceEvent, Never> {
        Empty().eraseToAnyPublisher()
    }
    
    var transcriptionPublisher: AnyPublisher<String, Never> {
        Empty().eraseToAnyPublisher()
    }

    var permissionPublisher: AnyPublisher<VoicePermissionSnapshot, Never> {
        Just(
            VoicePermissionSnapshot(
                microphone: .denied,
                speech: .denied
            )
        )
        .eraseToAnyPublisher()
    }

    var audioRoutePublisher: AnyPublisher<[AudioInputSource], Never> {
        Just([]).eraseToAnyPublisher()
    }

    func updateTriggerPhrase(_ phrase: String) {}

    func startListening() throws {}

    func stopListening() {}

    func refreshPermissions() {}

    func requestPermissionsIfNeeded() {}

    func selectPreferredInput(id: String?) {}
}

extension SpeechVoiceTriggerService {
    static func validateTriggerPhrase(_ phrase: String) -> (isValid: Bool, error: String?) {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return (false, "Trigger phrase cannot be empty")
        }
        
        if trimmed.count > 12 {
            return (false, "Trigger phrase must be 12 characters or less")
        }
        
        if trimmed.count < 2 {
            return (false, "Trigger phrase must be at least 2 characters")
        }
        
        // Only allow letters and spaces
        let allowedCharacters = CharacterSet.letters.union(.whitespaces)
        if trimmed.unicodeScalars.contains(where: { !allowedCharacters.contains($0) }) {
            return (false, "Only letters and spaces are allowed")
        }
        
        return (true, nil)
    }
}

private extension SpeechVoiceTriggerService {
    static func normalizeTrigger(_ phrase: String) -> String {
        phrase
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ensurePermissions() throws {
        let speechStatus = requestSpeechAuthorizationIfNeeded()
        let microphoneStatus = requestMicrophonePermissionIfNeeded()
        updatePermissionsSnapshot(
            microphone: microphoneStatus,
            speech: VoicePermissionStatus(speechStatus: speechStatus)
        )

        guard speechStatus == .authorized else {
            throw VoiceTriggerServiceError.speechPermissionDenied
        }

        guard microphoneStatus == .granted else {
            throw VoiceTriggerServiceError.microphonePermissionDenied
        }
    }

    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        
        // Deactivate first to allow input changes
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )
        
        // Set preferred input before activating
        if let preferredInputID,
           let preferredInput = session.availableInputs?.first(where: { $0.uid == preferredInputID }) {
            try session.setPreferredInput(preferredInput)
        } else {
            try? session.setPreferredInput(nil)
        }
        
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func installAudioTap() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.inputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
    }

    func scheduleRecognitionRestart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.shouldAttemptRestart else { return }
            guard !self.isRestarting else { return }
            self.restartRecognition(resetAudio: true)
        }
    }

    func refreshAudioRoute() {
        let session = AVAudioSession.sharedInstance()
        let availableInputs = session.availableInputs ?? []
        let currentInputIDs = Set(session.currentRoute.inputs.map { $0.uid })
        var sources = availableInputs.map { input in
            AudioInputSource(
                portDescription: input,
                isCurrent: currentInputIDs.contains(input.uid)
            )
        }

        if sources.isEmpty {
            sources = session.currentRoute.inputs.map { input in
                AudioInputSource(
                    portDescription: input,
                    isCurrent: true
                )
            }
        }

        if sources.isEmpty {
            sources = [
                AudioInputSource(
                    id: "built-in",
                    name: "iPhone Microphone",
                    kind: .builtIn,
                    isCurrent: true
                )
            ]
        }

        DispatchQueue.main.async { [audioRouteSubject] in
            audioRouteSubject.send(sources)
        }
    }

    func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let self else { return }
            self.refreshAudioRoute()
            guard self.isSessionRunning else { return }
            self.handleRouteChange(notification)
        }
    }

    func handleRouteChange(_ notification: Notification) {
        guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }

        #if DEBUG
        print("🎤 Audio route change: \(reason.rawValue)")
        #endif

        let shouldRestart: Bool
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .routeConfigurationChange:
            shouldRestart = true
        case .categoryChange:
            shouldRestart = false
        default:
            shouldRestart = false
        }

        guard shouldRestart, shouldAttemptRestart else {
            return
        }

        // Mark that we're handling a route change to prevent error callbacks from interfering
        isRestarting = true

        // Stop current recognition immediately
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest?.endAudio()
            self.recognitionRequest = nil
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
        }

        // Delay to allow audio route to fully switch before restarting recognition
        sessionQueue.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self else { return }
            guard self.shouldAttemptRestart else {
                self.isRestarting = false
                return
            }
            self.restartRecognition(resetAudio: true)
        }
    }

    func restartRecognition(resetAudio: Bool) {
        do {
            // Full audio engine reset
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.reset()
            
            try configureAudioSession()
            refreshAudioRoute()
            try startRecognitionLocked(resetAudio: resetAudio)
            isSessionRunning = true
            isRestarting = false
            eventSubject.send(.started)
        } catch {
            isSessionRunning = false
            isRestarting = false
            #if DEBUG
            print("Failed to restart speech recognition: \(error)")
            #endif
            eventSubject.send(.failure(error))
        }
    }

    func startRecognitionLocked(resetAudio: Bool) throws {
        guard speechRecognizer.isAvailable else {
            throw VoiceTriggerServiceError.speechRecognizerUnavailable
        }

        recognitionTask?.cancel()
        recognitionTask = nil

        recognitionRequest?.endAudio()
        recognitionRequest = nil
        resetTranscriptionMatchProgress()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        if resetAudio {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.reset()
            
            audioEngine.prepare()
            try audioEngine.start()
            installAudioTap()
        }

        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let transcription = result?.bestTranscription {
                self.evaluate(transcription: transcription)
            }

            if let error = error {
                // Don't update state if we're in the middle of a route change restart
                guard !self.isRestarting else { return }
                
                self.isSessionRunning = false

                #if DEBUG
                print("Speech recognition error: \(error.localizedDescription)")
                #endif

                let errorDesc = error.localizedDescription.lowercased()
                let isTransientError = errorDesc.contains("no speech") ||
                                       errorDesc.contains("speech detected") ||
                                       errorDesc.contains("retry") ||
                                       errorDesc.contains("cancelled")
                if !isTransientError {
                    self.eventSubject.send(.failure(error))
                }
                self.scheduleRecognitionRestart()
            } else if result?.isFinal == true {
                guard !self.isRestarting else { return }
                self.isSessionRunning = false
                self.scheduleRecognitionRestart()
            }
        }

        recognitionTask = task
    }

    func evaluate(transcription: SFTranscription) {
        let formatted = transcription.formattedString.lowercased()
        
        #if DEBUG
        print("🎤 Heard: \"\(transcription.formattedString)\"")
        #endif
        
        transcriptionSubject.send(transcription.formattedString)
        
        guard !normalizedTriggerPhrase.isEmpty else { return }
        lastMatchedCharacterCount = min(lastMatchedCharacterCount, formatted.count)

        let searchStartIndex = formatted.index(formatted.startIndex, offsetBy: lastMatchedCharacterCount)
        guard searchStartIndex < formatted.endIndex else { return }
        
        let searchText = String(formatted[searchStartIndex...])
        
        // Check for exact match first
        var matchEndIndex: String.Index?
        if let range = searchText.range(of: normalizedTriggerPhrase) {
            matchEndIndex = formatted.index(searchStartIndex, offsetBy: searchText.distance(from: searchText.startIndex, to: range.upperBound))
        }
        
        // Fuzzy matching: check for phonetic variations
        if matchEndIndex == nil {
            let variations = generatePhoneticVariations(for: normalizedTriggerPhrase)
            for variation in variations {
                if let range = searchText.range(of: variation) {
                    matchEndIndex = formatted.index(searchStartIndex, offsetBy: searchText.distance(from: searchText.startIndex, to: range.upperBound))
                    break
                }
            }
        }
        
        // Check without spaces (words run together)
        if matchEndIndex == nil {
            let noSpaceTrigger = normalizedTriggerPhrase.replacingOccurrences(of: " ", with: "")
            let noSpaceSearch = searchText.replacingOccurrences(of: " ", with: "")
            if noSpaceSearch.contains(noSpaceTrigger) {
                matchEndIndex = formatted.endIndex
            }
        }
        
        guard let endIndex = matchEndIndex else { return }

        let now = Date()
        if let lastTriggerDate, now.timeIntervalSince(lastTriggerDate) < triggerThrottle {
            lastMatchedCharacterCount = formatted.distance(from: formatted.startIndex, to: endIndex)
            return
        }

        lastTriggerDate = now
        lastMatchedCharacterCount = formatted.distance(from: formatted.startIndex, to: endIndex)

        #if DEBUG
        let snippet = transcription.formattedString
        print("Voice trigger heard (\(normalizedTriggerPhrase)) within transcription: \"\(snippet)\"")
        #endif
        subject.send(())
    }
    
    private func generatePhoneticVariations(for phrase: String) -> [String] {
        var variations: [String] = []
        
        // Common phonetic substitutions that work for any phrase
        let phoneticSubstitutions: [(String, String)] = [
            // Vowel variations
            ("ee", "i"), ("ee", "ea"), ("i", "ee"), ("i", "y"),
            ("a", "ah"), ("a", "uh"), ("e", "eh"), ("e", "i"),
            ("o", "oh"), ("o", "aw"), ("u", "oo"),
            // Consonant variations
            ("c", "k"), ("k", "c"), ("ph", "f"), ("f", "ph"),
            ("ck", "k"), ("ck", "c"),
            // Common mishearings
            ("er", "a"), ("er", "ur"), ("or", "er"),
            ("th", "d"), ("th", "t"),
        ]
        
        // Generate single-substitution variations
        for (from, to) in phoneticSubstitutions {
            if phrase.contains(from) {
                variations.append(phrase.replacingOccurrences(of: from, with: to))
            }
        }
        
        return variations
    }

    func requestSpeechAuthorizationIfNeeded() -> SFSpeechRecognizerAuthorizationStatus {
        let current = SFSpeechRecognizer.authorizationStatus()
        guard current == .notDetermined else { return current }

        let semaphore = DispatchSemaphore(value: 0)
        var resolvedStatus = current
        SFSpeechRecognizer.requestAuthorization { status in
            resolvedStatus = status
            semaphore.signal()
        }
        semaphore.wait()
        return resolvedStatus
    }

    func requestMicrophonePermissionIfNeeded() -> VoicePermissionStatus {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                let semaphore = DispatchSemaphore(value: 0)
                var status: VoicePermissionStatus = .notDetermined
                AVAudioApplication.requestRecordPermission { allowed in
                    status = allowed ? .granted : .denied
                    semaphore.signal()
                }
                semaphore.wait()
                return status
            @unknown default:
                return .unknown
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            case .undetermined:
                let semaphore = DispatchSemaphore(value: 0)
                var status: VoicePermissionStatus = .notDetermined
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    status = allowed ? .granted : .denied
                    semaphore.signal()
                }
                semaphore.wait()
                return status
            @unknown default:
                return .unknown
            }
        }
    }

    func resetTranscriptionMatchProgress() {
        lastMatchedCharacterCount = 0
    }

    func updatePermissionsSnapshot(
        microphone: VoicePermissionStatus,
        speech: VoicePermissionStatus
    ) {
        DispatchQueue.main.async { [permissionSubject] in
            permissionSubject.send(
                VoicePermissionSnapshot(
                    microphone: microphone,
                    speech: speech
                )
            )
        }
    }
}

extension SpeechVoiceTriggerService {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            scheduleRecognitionRestart()
        } else {
            isSessionRunning = false
            eventSubject.send(.failure(VoiceTriggerServiceError.speechRecognizerUnavailable))
        }
    }
}
