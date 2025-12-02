import SwiftUI

struct ShutterButton: View {
    let scale: CGFloat
    let timerDuration: TimerDuration
    let isTimerRunning: Bool
    let timerCountdown: Int
    let action: () -> Void
    let cancelAction: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            if isTimerRunning {
                cancelAction()
            } else {
                action()
            }
        } label: {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Inner circle
                Circle()
                    .fill(Color.white)
                    .frame(width: 66, height: 66)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                
                // Content based on state
                if isTimerRunning {
                    // Show stop icon to cancel
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 28, height: 28)
                } else if timerDuration != .off {
                    // Show timer icon with duration
                    VStack(spacing: 2) {
                        Image(systemName: "timer")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black.opacity(0.6))
                        
                        Text(timerDuration.displayName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.black.opacity(0.6))
                    }
                }
            }
            .scaleEffect(scale)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        isPressed = false
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: isTimerRunning)
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 40) {
            ShutterButton(scale: 1.0, timerDuration: .off, isTimerRunning: false, timerCountdown: 0, action: {}, cancelAction: {})
            ShutterButton(scale: 1.0, timerDuration: .three, isTimerRunning: false, timerCountdown: 0, action: {}, cancelAction: {})
            ShutterButton(scale: 1.0, timerDuration: .five, isTimerRunning: true, timerCountdown: 3, action: {}, cancelAction: {})
        }
    }
}
