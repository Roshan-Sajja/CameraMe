import AVFoundation
import Foundation

enum AudioInputKind: String {
    case builtIn = "Built-in"
    case bluetooth = "Bluetooth"
    case wired = "Wired Headphones"
    case usb = "USB Audio"
    case external = "External"
}

struct AudioInputSource: Identifiable, Equatable {
    let id: String
    let name: String
    let kind: AudioInputKind
    let isCurrent: Bool
}

extension AudioInputSource {
    init(portDescription: AVAudioSessionPortDescription, isCurrent: Bool) {
        let kind: AudioInputKind
        switch portDescription.portType {
        case .bluetoothHFP, .bluetoothA2DP, .bluetoothLE:
            kind = .bluetooth
        case .headsetMic:
            kind = .wired
        case .usbAudio:
            kind = .usb
        case .builtInMic:
            kind = .builtIn
        default:
            kind = .external
        }

        self.init(
            id: portDescription.uid,
            name: portDescription.portName,
            kind: kind,
            isCurrent: isCurrent
        )
    }
}
