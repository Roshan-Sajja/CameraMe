import Combine
import Foundation

/// Abstraction that will own the speech recognizer + keyword spotting pipeline.
protocol VoiceTriggerService {
    /// Emits whenever the configured keyword/phrase is detected.
    var triggerPublisher: AnyPublisher<Void, Never> { get }

    /// Updates the phrase we listen for while the session is live.
    func updateTriggerPhrase(_ phrase: String)

    /// Starts streaming microphone audio into the recognition pipeline.
    func startListening() throws

    /// Stops streaming audio and tears down resources.
    func stopListening()
}

final class PlaceholderVoiceTriggerService: VoiceTriggerService {
    private let subject = PassthroughSubject<Void, Never>()

    var triggerPublisher: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func updateTriggerPhrase(_ phrase: String) {
        // TODO: Wire up to Speech framework once implementation begins.
    }

    func startListening() throws {
        // TODO: Request permission + spin up AVAudioEngine/SFSpeechRecognizer.
    }

    func stopListening() {
        // TODO: Stop audio engine + recognition requests.
    }
}
