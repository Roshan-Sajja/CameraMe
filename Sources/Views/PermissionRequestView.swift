import SwiftUI

struct PermissionRequestView: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var animateGradient = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    Color(hex: "1a1a2e"),
                    Color(hex: "16213e"),
                    Color(hex: "0f3460")
                ],
                startPoint: animateGradient ? .topLeading : .bottomLeading,
                endPoint: animateGradient ? .bottomTrailing : .topTrailing
            )
            .ignoresSafeArea()
            .onAppear {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateGradient.toggle()
                }
            }
            
            // Floating circles for depth
            GeometryReader { geo in
                Circle()
                    .fill(Color(hex: "e94560").opacity(0.1))
                    .frame(width: 300, height: 300)
                    .blur(radius: 60)
                    .offset(x: -50, y: geo.size.height * 0.1)
                
                Circle()
                    .fill(Color(hex: "0f3460").opacity(0.3))
                    .frame(width: 200, height: 200)
                    .blur(radius: 40)
                    .offset(x: geo.size.width * 0.6, y: geo.size.height * 0.7)
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                // App icon and title
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .shadow(color: Color(hex: "e94560").opacity(0.5), radius: 20)
                        
                        Image(systemName: "camera.fill")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showContent ? 1 : 0.5)
                    .opacity(showContent ? 1 : 0)
                    
                    VStack(spacing: 8) {
                        Text("CameraMe")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Voice-activated photography")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                }
                
                Spacer()
                
                // Permission cards
                VStack(spacing: 16) {
                    PermissionCard(
                        icon: "camera.fill",
                        title: "Camera Access",
                        description: "To capture your photos",
                        accentColor: Color(hex: "e94560")
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    PermissionCard(
                        icon: "mic.fill",
                        title: "Microphone Access",
                        description: "To hear your voice commands",
                        accentColor: Color(hex: "ff6b6b")
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    PermissionCard(
                        icon: "photo.fill",
                        title: "Photo Library Access",
                        description: "To save your photos",
                        accentColor: Color(hex: "4ecdc4")
                    )
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Continue button
                Button {
                    permissionManager.requestAllPermissions()
                } label: {
                    HStack(spacing: 12) {
                        Text("Continue")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "e94560"), Color(hex: "ff6b6b")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: Color(hex: "e94560").opacity(0.4), radius: 15, y: 8)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                showContent = true
            }
        }
    }
}

#Preview {
    PermissionRequestView(permissionManager: PermissionManager())
        .preferredColorScheme(.dark)
}

