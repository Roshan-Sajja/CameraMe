import SwiftUI

struct AspectRatioOverlay: View {
    let aspectRatio: AspectRatio
    let geometry: GeometryProxy
    
    var body: some View {
        // Use screen bounds for consistent sizing (original approach)
        let screenBounds = UIScreen.main.bounds
        let screenWidth = screenBounds.width
        let screenHeight = screenBounds.height
        
        // Target aspect ratio (height/width)
        let targetRatio: CGFloat
        switch aspectRatio {
        case .ratio4x3:
            // 4:3 (3 wide x 4 tall in portrait)
            targetRatio = 4.0 / 3.0
        case .ratio1x1:
            targetRatio = 1.0           // Square (unchanged)
        case .ratio16x9:
            targetRatio = 16.0 / 9.0    // 9 wide × 16 tall
        }
        
        // Calculate visible area - fills screen width, centered vertically
        let visibleHeight = screenWidth * targetRatio
        let barHeight = max(0, (screenHeight - visibleHeight) / 2)
        
        return ZStack {
            // Top bar
            VStack {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: barHeight)
                Spacer()
            }
            
            // Bottom bar
            VStack {
                Spacer()
                Rectangle()
                    .fill(Color.black)
                    .frame(height: barHeight)
            }
        }
        .allowsHitTesting(false)
    }
}
