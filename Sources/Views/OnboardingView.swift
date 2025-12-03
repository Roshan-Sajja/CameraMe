import SwiftUI

struct OnboardingView: View {
    let triggerPhrase: String
    let onDismiss: () -> Void
    
    @State private var animatePhrase = false
    
    private let orange = Color(hex: "f97316")
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // App icon / illustration
                ZStack {
                    Circle()
                        .fill(orange)
                        .frame(width: 120, height: 120)
                        .shadow(color: orange.opacity(0.4), radius: 20, x: 0, y: 10)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 40)
                
                // Title
                Text("CameraMe")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.bottom, 12)
                
                // Subtitle
                Text("Hands-free photo capture")
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 50)
                
                // Trigger phrase card
                VStack(spacing: 16) {
                    Text("Just say")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                    
                    HStack(spacing: 12) {
                        Image(systemName: "quote.opening")
                            .font(.system(size: 20))
                            .foregroundColor(orange)
                        
                        Text(triggerPhrase)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .scaleEffect(animatePhrase ? 1.05 : 1.0)
                        
                        Image(systemName: "quote.closing")
                            .font(.system(size: 20))
                            .foregroundColor(orange)
                    }
                    
                    Text("to take a photo")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.vertical, 30)
                .padding(.horizontal, 40)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Features list
                VStack(spacing: 16) {
                    FeatureRow(icon: "waveform", text: "Voice-activated capture", accentColor: orange)
                    FeatureRow(icon: "timer", text: "Countdown timer support", accentColor: orange)
                    FeatureRow(icon: "gearshape", text: "Customizable trigger phrase", accentColor: orange)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
                
                // Get Started button
                Button(action: onDismiss) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
            ) {
                animatePhrase = true
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String
    let accentColor: Color
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(accentColor)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(triggerPhrase: "Camera me") {}
}

