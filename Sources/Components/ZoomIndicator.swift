import SwiftUI

struct ZoomIndicator: View {
    let zoom: CGFloat
    
    @State private var isVisible = false
    @State private var previousZoom: CGFloat = 1.0
    @State private var showChange = false
    
    var body: some View {
        HStack(spacing: 6) {
            // Zoom icon with animation
            Image(systemName: zoom > previousZoom ? "plus.magnifyingglass" : "minus.magnifyingglass")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .opacity(showChange ? 1 : 0)
                .scaleEffect(showChange ? 1 : 0.5)
            
            // Zoom value
            Text(String(format: "%.1fx", zoom))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.5))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isVisible = true
            }
        }
        .onChange(of: zoom) { oldValue, newValue in
            previousZoom = oldValue
            
            // Show direction indicator briefly
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                showChange = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.2)) {
                    showChange = false
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            ZoomIndicator(zoom: 1.0)
            ZoomIndicator(zoom: 2.5)
            ZoomIndicator(zoom: 0.5)
        }
    }
}
