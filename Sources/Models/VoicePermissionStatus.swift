import AVFAudio
import AVFoundation
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

struct VoicePermissionSnapshot {
    let microphone: VoicePermissionStatus
    let speech: VoicePermissionStatus

    var canListen: Bool {
        microphone.isGranted && speech.isGranted
    }
}

enum VoicePermissionReader {
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
}
