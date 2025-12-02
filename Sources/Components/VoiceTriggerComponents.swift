import SwiftUI

// Mic button in top bar - heartbeat animation when listening
struct VoiceTriggerBadge: View {
    let isListening: Bool
    let action: () -> Void
    @State private var heartbeatPhase: Int = 0
    
    // Timer for heartbeat
    let heartbeatTimer = Timer.publish(every: 0.8, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            ZStack {
                // Glow effect when listening
                Circle()
                    .fill(Color.yellow.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .scaleEffect(isListening ? 1.3 : 1.0)
                    .opacity(isListening ? 0.4 : 0.0)
                    .animation(.easeInOut(duration: 0.3), value: isListening)
                
                // Background circle
                Circle()
                    .fill(isListening ? Color.yellow.opacity(0.2) : Color.black.opacity(0.4))
                    .frame(width: 44, height: 44)
                
                // Mic icon with heartbeat
                Image(systemName: isListening ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isListening ? .yellow : .white.opacity(0.6))
                    .scaleEffect(isListening ? heartbeatScale : 1.0)
                    .animation(.easeOut(duration: 0.15), value: heartbeatPhase)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isListening)
        .onReceive(heartbeatTimer) { _ in
            if isListening {
                doHeartbeat()
            }
        }
        .onChange(of: isListening) { _, listening in
            if !listening {
                heartbeatPhase = 0
            }
        }
    }
    
    private var heartbeatScale: CGFloat {
        switch heartbeatPhase % 4 {
        case 1: return 1.15
        case 2: return 1.0
        case 3: return 1.1
        default: return 1.0
        }
    }
    
    private func doHeartbeat() {
        // First beat
        heartbeatPhase = 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            heartbeatPhase = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            heartbeatPhase = 3
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            heartbeatPhase = 0
        }
    }
}

// Bottom pill button for Voice toggle
struct VoiceTogglePill: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 14))
                Text(isEnabled ? "Voice On" : "Voice Off")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isEnabled ? Color(hex: "6366f1") : Color.white.opacity(0.15))
            )
        }
    }
}

// Bottom pill for aspect ratio
struct AspectRatioPill: View {
    let ratio: String
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                Text(ratio)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.15))
            )
        }
    }
}

// Voice button (left side of shutter)
struct VoiceButton: View {
    let isEnabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? Color(hex: "6366f1").opacity(0.3) : Color.white.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: isEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                Text("Voice")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }
}

// Flip button (right side of shutter)
struct FlipButton: View {
    let action: () -> Void
    @State private var rotation: Double = 0
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                rotation += 180
            }
            action()
        }) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(rotation))
            }
        }
    }
}

// Photo preview button (left side of shutter)
struct PhotoPreviewButton: View {
    let image: UIImage?
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            action()
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 60, height: 60)
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 22))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .disabled(image == nil)
    }
}

// "Say the magic word" header
struct TriggerPhraseHeader: View {
    let phrase: String
    let isListening: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Text("Say the magic word")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
            
            Text("\"\(phrase)\"")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .opacity(isListening ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.3), value: isListening)
    }
}

#Preview("Badge") {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            VoiceTriggerBadge(isListening: true) {}
            VoiceTriggerBadge(isListening: false) {}
        }
    }
}

#Preview("Pills") {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            VoiceTogglePill(isEnabled: true) {}
            VoiceTogglePill(isEnabled: false) {}
            AspectRatioPill(ratio: "4:3") {}
        }
    }
}

#Preview("Buttons") {
    ZStack {
        Color.black
        HStack(spacing: 40) {
            VoiceButton(isEnabled: true) {}
            FlipButton {}
        }
    }
}
