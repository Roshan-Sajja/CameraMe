import SwiftUI

struct AspectRatioOverlay: View {
    let aspectRatio: AspectRatio
    let geometry: GeometryProxy
    
    var body: some View {
        let screenWidth = geometry.size.width
        let screenHeight = geometry.size.height
        
        // Target aspect ratio (height/width)
        let targetRatio = aspectRatio.multiplier
        
        // Calculate visible area - fills width, centered vertically, never adding side bars
        let visibleHeight = min(screenWidth * targetRatio, screenHeight)
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
