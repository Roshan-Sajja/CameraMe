import SwiftUI

struct LensSelectorView: View {
    @ObservedObject var cameraController: CameraController
    let controlRotation: Angle
    
    @State private var selectedIndex: Int = 0
    @State private var isVisible = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(cameraController.availableLenses.enumerated()), id: \.element) { index, lens in
                LensButton(
                    lens: lens,
                    isSelected: cameraController.currentLens == lens,
                    index: index,
                    controlRotation: controlRotation
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        cameraController.switchLens(lens)
                        selectedIndex = index
                    }
                    // Haptic
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                }
                .opacity(isVisible ? 1 : 0)
                .offset(y: isVisible ? 0 : 20)
                .animation(
                    .spring(response: 0.5, dampingFraction: 0.7)
                    .delay(Double(index) * 0.05),
                    value: isVisible
                )
            }
        }
        .onAppear {
            isVisible = true
            if let index = cameraController.availableLenses.firstIndex(of: cameraController.currentLens) {
                selectedIndex = index
            }
        }
    }
}

struct LensButton: View {
    let lens: CameraLens
    let isSelected: Bool
    let index: Int
    let controlRotation: Angle
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.15))
                    .frame(width: 32, height: 32)
                
                Text(lens.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(isSelected ? .black : .white)
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .rotationEffect(controlRotation)
        .animation(.easeInOut(duration: 0.25), value: controlRotation)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            isPressed = true
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isPressed = false
                    }
                }
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

#Preview {
    ZStack {
        Color.black
        LensSelectorView(
            cameraController: CameraController(),
            controlRotation: .zero
        )
    }
}
