import SwiftUI

// Rule of thirds grid overlay - only within camera preview area
struct GridOverlay: View {
    let aspectRatio: AspectRatio
    
    var body: some View {
        GeometryReader { geometry in
            let screenWidth = geometry.size.width
            let screenHeight = geometry.size.height
            
            // Calculate the visible camera area based on aspect ratio
            let visibleRect = calculateVisibleRect(screenWidth: screenWidth, screenHeight: screenHeight)
            
            Path { path in
                // Vertical lines (rule of thirds)
                let thirdWidth = visibleRect.width / 3
                
                path.move(to: CGPoint(x: visibleRect.minX + thirdWidth, y: visibleRect.minY))
                path.addLine(to: CGPoint(x: visibleRect.minX + thirdWidth, y: visibleRect.maxY))
                
                path.move(to: CGPoint(x: visibleRect.minX + thirdWidth * 2, y: visibleRect.minY))
                path.addLine(to: CGPoint(x: visibleRect.minX + thirdWidth * 2, y: visibleRect.maxY))
                
                // Horizontal lines (rule of thirds)
                let thirdHeight = visibleRect.height / 3
                
                path.move(to: CGPoint(x: visibleRect.minX, y: visibleRect.minY + thirdHeight))
                path.addLine(to: CGPoint(x: visibleRect.maxX, y: visibleRect.minY + thirdHeight))
                
                path.move(to: CGPoint(x: visibleRect.minX, y: visibleRect.minY + thirdHeight * 2))
                path.addLine(to: CGPoint(x: visibleRect.maxX, y: visibleRect.minY + thirdHeight * 2))
            }
            .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
    
    private func calculateVisibleRect(screenWidth: CGFloat, screenHeight: CGFloat) -> CGRect {
        switch aspectRatio {
        case .ratio4x3:
            // 4:3 (3 wide x 4 tall in portrait) - fills width, centered vertically
            let visibleHeight = screenWidth * (4.0 / 3.0)
            let yOffset = (screenHeight - visibleHeight) / 2
            return CGRect(x: 0, y: yOffset, width: screenWidth, height: visibleHeight)
            
        case .ratio1x1:
            // Square - fills width, centered vertically
            let size = screenWidth
            let yOffset = (screenHeight - size) / 2
            return CGRect(x: 0, y: yOffset, width: size, height: size)
            
        case .ratio16x9:
            // 16:9 (9 wide x 16 tall) - fills width, with top/bottom bars
            let visibleHeight = screenWidth * (16.0 / 9.0)
            let yOffset = (screenHeight - visibleHeight) / 2
            return CGRect(x: 0, y: yOffset, width: screenWidth, height: visibleHeight)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        GridOverlay(aspectRatio: .ratio4x3)
    }
}
