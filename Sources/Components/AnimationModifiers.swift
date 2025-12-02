import SwiftUI

// MARK: - Custom Animation Modifiers

/// Bounce animation for buttons
struct BouncePress: ViewModifier {
    @State private var isPressed = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action()
                    }
            )
    }
}

/// Staggered fade-in animation for lists
struct StaggeredAppear: ViewModifier {
    let index: Int
    @State private var isVisible = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.1)) {
                    isVisible = true
                }
            }
    }
}

/// Pulse animation for active states
struct PulseAnimation: ViewModifier {
    let isActive: Bool
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .scaleEffect(isPulsing ? 1.5 : 1.0)
                    .opacity(isPulsing ? 0 : 0.8)
            )
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                } else {
                    isPulsing = false
                }
            }
            .onAppear {
                if isActive {
                    withAnimation(.easeOut(duration: 1.0).repeatForever(autoreverses: false)) {
                        isPulsing = true
                    }
                }
            }
    }
}

/// Shake animation for errors
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX:
            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
            y: 0))
    }
}

/// Glow effect for active elements
struct GlowEffect: ViewModifier {
    let color: Color
    let isActive: Bool
    @State private var glowOpacity: CGFloat = 0.5
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(glowOpacity) : .clear, radius: 10)
            .shadow(color: isActive ? color.opacity(glowOpacity * 0.5) : .clear, radius: 20)
            .onChange(of: isActive) { _, active in
                if active {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        glowOpacity = 1.0
                    }
                } else {
                    withAnimation(.easeOut(duration: 0.3)) {
                        glowOpacity = 0.5
                    }
                }
            }
    }
}

/// Smooth slide transition
struct SlideTransition: ViewModifier {
    let edge: Edge
    let isVisible: Bool
    
    func body(content: Content) -> some View {
        content
            .offset(x: xOffset, y: yOffset)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
    }
    
    private var xOffset: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .leading: return -50
        case .trailing: return 50
        default: return 0
        }
    }
    
    private var yOffset: CGFloat {
        guard !isVisible else { return 0 }
        switch edge {
        case .top: return -50
        case .bottom: return 50
        default: return 0
        }
    }
}

// MARK: - View Extensions

extension View {
    func bouncePress(action: @escaping () -> Void) -> some View {
        modifier(BouncePress(action: action))
    }
    
    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
    
    func pulseWhen(_ isActive: Bool) -> some View {
        modifier(PulseAnimation(isActive: isActive))
    }
    
    func shake(animatableData: CGFloat) -> some View {
        modifier(ShakeEffect(animatableData: animatableData))
    }
    
    func glow(color: Color, when isActive: Bool) -> some View {
        modifier(GlowEffect(color: color, isActive: isActive))
    }
    
    func slideIn(from edge: Edge, when isVisible: Bool) -> some View {
        modifier(SlideTransition(edge: edge, isVisible: isVisible))
    }
}

// MARK: - Custom Transitions

extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        )
    }
    
    static var blur: AnyTransition {
        .modifier(
            active: BlurModifier(isActive: true),
            identity: BlurModifier(isActive: false)
        )
    }
}

struct BlurModifier: ViewModifier {
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isActive ? 10 : 0)
            .opacity(isActive ? 0 : 1)
    }
}

