import SwiftUI

struct PermissionDeniedView: View {
    @ObservedObject var permissionManager: PermissionManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            Color(hex: "1a1a2e")
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // Warning icon
                ZStack {
                    Circle()
                        .fill(Color(hex: "e94560").opacity(0.15))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(Color(hex: "e94560"))
                }
                
                VStack(spacing: 12) {
                    Text("Permissions Required")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("CameraMe needs camera and microphone access to work. Please enable them in Settings.")
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Permission status cards
                VStack(spacing: 12) {
                    PermissionStatusCard(
                        title: "Camera",
                        isGranted: permissionManager.cameraStatus == .authorized
                    )
                    
                    PermissionStatusCard(
                        title: "Microphone",
                        isGranted: permissionManager.microphoneStatus.isGranted
                    )
                    
                    PermissionStatusCard(
                        title: "Speech Recognition",
                        isGranted: permissionManager.speechStatus.isGranted
                    )
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Open Settings button
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "gear")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text("Open Settings")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
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
                
                Button {
                    permissionManager.checkPermissions()
                } label: {
                    Text("Check Again")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.bottom, 50)
            }
        }
    }
}

#Preview {
    PermissionDeniedView(permissionManager: PermissionManager())
        .preferredColorScheme(.dark)
}

