import SwiftUI

struct TimerCountdownOverlay: View {
    let countdown: Int
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Simple countdown number
            Text("\(countdown)")
                .font(.system(size: 120, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.3), radius: 10)
                .scaleEffect(scale)
                .opacity(opacity)
        }
        .onAppear {
            animateIn()
        }
        .onChange(of: countdown) { _, _ in
            // Haptic feedback
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            
            // Quick bounce animation
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                scale = 0.8
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    scale = 1.0
                }
            }
        }
    }
    
    private func animateIn() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            scale = 1.0
            opacity = 1.0
        }
    }
}

#Preview {
    TimerCountdownOverlay(countdown: 3)
}
