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
        let targetRatio = aspectRatio.multiplier
        let targetHeight = min(screenWidth * targetRatio, screenHeight)
        let yOffset = (screenHeight - targetHeight) / 2
        return CGRect(x: 0, y: yOffset, width: screenWidth, height: targetHeight)
    }
}

#Preview {
    ZStack {
        Color.black
        GridOverlay(aspectRatio: .ratio4x3)
    }
}
