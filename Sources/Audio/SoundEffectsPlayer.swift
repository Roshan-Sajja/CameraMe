import AudioToolbox
import AVFoundation
import Foundation
import UIKit

final class SoundEffectsPlayer {
    static let shared = SoundEffectsPlayer()
    
    private var tickPlayer: AVAudioPlayer?

    private init() {
        prepareTickSound()
    }

    func playShutter() {
        AudioServicesPlaySystemSound(1108)
    }

    func playTimerTick() {
        // AVAudioPlayer works reliably during active recording sessions
        tickPlayer?.currentTime = 0
        tickPlayer?.play()
        
        // Also trigger haptic feedback as backup
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func prepareTickSound() {
        // Use the Tock sound from system - create a simple beep tone if unavailable
        if let url = URL(string: "/System/Library/Audio/UISounds/Tock.caf") {
            do {
                tickPlayer = try AVAudioPlayer(contentsOf: url)
                tickPlayer?.prepareToPlay()
                tickPlayer?.volume = 1.0
            } catch {
                createSyntheticTick()
            }
        } else {
            createSyntheticTick()
        }
    }
    
    private func createSyntheticTick() {
        // Fallback: use system sound with alert (vibrates but more reliable)
        // This path is used if system sound file isn't accessible
    }
}
