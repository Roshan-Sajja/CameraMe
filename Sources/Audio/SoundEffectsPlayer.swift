import AudioToolbox
import AVFoundation
import Foundation
import UIKit

final class SoundEffectsPlayer {
    static let shared = SoundEffectsPlayer()
    
    private var tickPlayer: AVAudioPlayer?
    private var shutterPlayer: AVAudioPlayer?

    private init() {
        prepareSounds()
    }

    func playShutter() {
        overrideToSpeaker()
        
        // Use AVAudioPlayer for reliable playback during active recording sessions
        shutterPlayer?.currentTime = 0
        shutterPlayer?.play()
    }

    func playTimerTick() {
        overrideToSpeaker()
        
        // AVAudioPlayer works reliably during active recording sessions
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
        
        // Also trigger haptic feedback as backup
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func overrideToSpeaker() {
        let session = AVAudioSession.sharedInstance()
        
        // Check if we're using external audio (Bluetooth, headphones)
        let outputs = session.currentRoute.outputs
        let hasExternalOutput = outputs.contains { output in
            switch output.portType {
            case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .headphones, .headsetMic, .usbAudio, .carAudio:
                return true
            default:
                return false
            }
        }
        
        // Only override to speaker if no external output is connected
        if !hasExternalOutput {
            do {
                try session.overrideOutputAudioPort(.speaker)
            } catch {
                #if DEBUG
                print("SoundEffectsPlayer: Failed to override to speaker: \(error)")
                #endif
            }
        }
    }
    
    private func prepareSounds() {
        // Shutter sound
        if let url = URL(string: "/System/Library/Audio/UISounds/photoShutter.caf") {
            do {
                shutterPlayer = try AVAudioPlayer(contentsOf: url)
                shutterPlayer?.prepareToPlay()
                shutterPlayer?.volume = 1.0
            } catch {
                #if DEBUG
                print("SoundEffectsPlayer: Failed to load photoShutter.caf")
                #endif
            }
        }
        
        // Timer tick sound
        if let url = URL(string: "/System/Library/Audio/UISounds/Tock.caf") {
            do {
                tickPlayer = try AVAudioPlayer(contentsOf: url)
                tickPlayer?.prepareToPlay()
                tickPlayer?.volume = 1.0
            } catch {
                #if DEBUG
                print("SoundEffectsPlayer: Failed to load Tock.caf")
                #endif
            }
        }
    }
}
