import SwiftUI

struct TopControlsBar: View {
    @ObservedObject var cameraController: CameraController
    @ObservedObject var voiceViewModel: VoiceTriggerViewModel
    @Binding var showSettings: Bool
    let onVoiceToggle: () -> Void
    let controlRotation: Angle
    let topPadding: CGFloat
    
    @State private var isVisible = false
    @State private var settingsRotation: Double = 0
    
    var body: some View {
        HStack {
            // Flash button (cycles through auto, on, off)
            Button {
                cameraController.cycleFlashMode()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                FlashButton(mode: cameraController.flashMode)
            }
            .rotationEffect(controlRotation)
            .animation(.easeInOut(duration: 0.25), value: controlRotation)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
            
            // Aspect ratio toggle button
            Button {
                cameraController.cycleAspectRatio()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                AspectRatioButton(ratio: cameraController.aspectRatio.rawValue)
            }
            .rotationEffect(controlRotation)
            .animation(.easeInOut(duration: 0.25), value: controlRotation)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
            
            // Mic button (center)
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                onVoiceToggle()
            } label: {
                MicButton(isListening: voiceViewModel.isListening)
            }
            .rotationEffect(controlRotation)
            .animation(.easeInOut(duration: 0.25), value: controlRotation)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
            
            // Timer toggle button
            Button {
                cameraController.cycleTimerDuration()
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                TimerButton(duration: cameraController.timerDuration)
            }
            .rotationEffect(controlRotation)
            .animation(.easeInOut(duration: 0.25), value: controlRotation)
            .opacity(isVisible ? 1 : 0)
            
            Spacer()
            
            // Settings button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    settingsRotation += 90
                }
                showSettings = true
            } label: {
                IconButton(icon: "gearshape.fill", isActive: false)
            }
            .rotationEffect(controlRotation)
            .animation(.easeInOut(duration: 0.25), value: controlRotation)
            .opacity(isVisible ? 1 : 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, topPadding)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.1)) {
                isVisible = true
            }
        }
    }
}

struct AspectRatioButton: View {
    let ratio: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12))
            Text(ratio)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct TimerButton: View {
    let duration: TimerDuration
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "timer")
                .font(.system(size: 12))
            Text(duration == .off ? "Off" : duration.displayName)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(duration != .off ? Color(hex: "f97316") : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct FlashButton: View {
    let mode: FlashMode
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: mode.icon)
                .font(.system(size: 12))
            Text(mode.rawValue)
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(mode == .on ? Color(hex: "f97316") : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct MicButton: View {
    let isListening: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 12))
            Text(isListening ? "On" : "Off")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(isListening ? Color(hex: "f97316") : .white)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.4))
        )
    }
}

struct IconButton: View {
    let icon: String
    let isActive: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.4))
                .frame(width: 44, height: 44)
            
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(isActive ? Color(hex: "e94560") : .white)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack {
            TopControlsBar(
                cameraController: CameraController(),
                voiceViewModel: VoiceTriggerViewModel(),
                showSettings: .constant(false),
                onVoiceToggle: {},
                controlRotation: .zero,
                topPadding: 12
            )
            Spacer()
        }
    }
}
