import AVFoundation
import AVFAudio
import Combine
import Foundation
import Speech

/// Lifecycle updates for the listening session so UI can reflect actual state.
enum VoiceTriggerServiceEvent {
    case started
    case stopped
    case failure(Error)
}

/// Abstraction that will own the speech recognizer + keyword spotting pipeline.
protocol VoiceTriggerService {
    /// Emits whenever the configured keyword/phrase is detected.
    var triggerPublisher: AnyPublisher<Void, Never> { get }

    /// Emits lifecycle and error events from the microphone/recognizer pipeline.
    var eventPublisher: AnyPublisher<VoiceTriggerServiceEvent, Never> { get }
    
    /// Emits the current transcription text for testing/debugging.
    var transcriptionPublisher: AnyPublisher<String, Never> { get }

    /// Updates the phrase we listen for while the session is live.
    func updateTriggerPhrase(_ phrase: String)

    /// Starts streaming microphone audio into the recognition pipeline.
    func startListening() throws

    /// Stops streaming audio and tears down resources.
    func stopListening()
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

/// Concrete implementation backed by AVAudioEngine + `SFSpeechRecognizer`.
final class SpeechVoiceTriggerService: NSObject, VoiceTriggerService, SFSpeechRecognizerDelegate {
    private let subject = PassthroughSubject<Void, Never>()
    private let eventSubject = PassthroughSubject<VoiceTriggerServiceEvent, Never>()
    private let transcriptionSubject = PassthroughSubject<String, Never>()
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

    var triggerPublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    var eventPublisher: AnyPublisher<VoiceTriggerServiceEvent, Never> {
        eventSubject.eraseToAnyPublisher()
    }
    
    var transcriptionPublisher: AnyPublisher<String, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }

    init(locale: Locale = Locale(identifier: "en-US"), initialTriggerPhrase: String = "camera me") throws {
#if targetEnvironment(simulator)
        throw VoiceTriggerServiceError.simulatorUnsupported
#endif
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            throw VoiceTriggerServiceError.speechRecognizerUnavailable
        }

        speechRecognizer = recognizer
        defaultTriggerPhrase = initialTriggerPhrase
        normalizedTriggerPhrase = SpeechVoiceTriggerService.normalizeTrigger(initialTriggerPhrase)

        super.init()

        speechRecognizer.delegate = self
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
        try configureAudioSession()

        var startError: Error?
        sessionQueue.sync {
            do {
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
}

/// Lightweight fallback that satisfies the protocol when speech recognition
/// cannot be initialized (e.g., running in Simulator without permissions).
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

    func updateTriggerPhrase(_ phrase: String) {}

    func startListening() throws {}

    func stopListening() {}
}

// MARK: - Private Helpers

private extension SpeechVoiceTriggerService {
    static func normalizeTrigger(_ phrase: String) -> String {
        phrase
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func ensurePermissions() throws {
        let speechStatus = requestSpeechAuthorizationIfNeeded()
        guard speechStatus == .authorized else {
            throw VoiceTriggerServiceError.speechPermissionDenied
        }

        let microphoneGranted = requestMicrophonePermissionIfNeeded()
        guard microphoneGranted else {
            throw VoiceTriggerServiceError.microphonePermissionDenied
        }
    }

    func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    func installAudioTap() {
        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
    }

    func scheduleRecognitionRestart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.shouldAttemptRestart else { return }
            do {
                let needsAudioReset = !self.audioEngine.isRunning
                try self.startRecognitionLocked(resetAudio: needsAudioReset)
                self.isSessionRunning = true
                self.eventSubject.send(.started)
            } catch {
                self.isSessionRunning = false
                #if DEBUG
                print("Failed to restart speech recognition: \(error)")
                #endif
                self.eventSubject.send(.failure(error))
            }
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
            installAudioTap()
            audioEngine.prepare()
            try audioEngine.start()
        }

        let task = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let transcription = result?.bestTranscription {
                self.evaluate(transcription: transcription)
            }

            if let error = error {
                #if DEBUG
                print("Speech recognition error: \(error.localizedDescription)")
                #endif
                self.isSessionRunning = false
                
                // Don't send failure events for transient errors like "No speech detected"
                // These are expected and the service will auto-restart
                let errorDesc = error.localizedDescription.lowercased()
                let isTransientError = errorDesc.contains("no speech") || 
                                       errorDesc.contains("speech detected") ||
                                       errorDesc.contains("retry")
                if !isTransientError {
                    self.eventSubject.send(.failure(error))
                }
                self.scheduleRecognitionRestart()
            } else if result?.isFinal == true {
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
        
        // Send transcription for UI display
        transcriptionSubject.send(transcription.formattedString)
        
        guard !normalizedTriggerPhrase.isEmpty else { return }
        lastMatchedCharacterCount = min(lastMatchedCharacterCount, formatted.count)

        let searchStartIndex = formatted.index(formatted.startIndex, offsetBy: lastMatchedCharacterCount)
        guard searchStartIndex < formatted.endIndex else { return }

        guard let range = formatted.range(
            of: normalizedTriggerPhrase,
            options: [],
            range: searchStartIndex..<formatted.endIndex,
            locale: nil
        ) else {
            return
        }

        let now = Date()
        if let lastTriggerDate, now.timeIntervalSince(lastTriggerDate) < triggerThrottle {
            lastMatchedCharacterCount = formatted.distance(from: formatted.startIndex, to: range.upperBound)
            return
        }

        lastTriggerDate = now
        lastMatchedCharacterCount = formatted.distance(from: formatted.startIndex, to: range.upperBound)

        #if DEBUG
        let snippet = transcription.formattedString
        print("Voice trigger heard (\(normalizedTriggerPhrase)) within transcription: \"\(snippet)\"")
        #endif
        subject.send(())
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

    func requestMicrophonePermissionIfNeeded() -> Bool {
        if #available(iOS 17, *) {
            switch AVAudioApplication.shared.recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                let semaphore = DispatchSemaphore(value: 0)
                var granted = false
                AVAudioApplication.requestRecordPermission { allowed in
                    granted = allowed
                    semaphore.signal()
                }
                semaphore.wait()
                return granted
            @unknown default:
                return false
            }
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                return true
            case .denied:
                return false
            case .undetermined:
                let semaphore = DispatchSemaphore(value: 0)
                var granted = false
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    granted = allowed
                    semaphore.signal()
                }
                semaphore.wait()
                return granted
            @unknown default:
                return false
            }
        }
    }

    func resetTranscriptionMatchProgress() {
        lastMatchedCharacterCount = 0
    }
}

// MARK: - SFSpeechRecognizerDelegate

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
