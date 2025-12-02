import SwiftUI

struct PhotoPreviewView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
            
            // Image with gestures
            GeometryReader { geometry in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale * magnifyBy)
                    .offset(offset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .gesture(
                        MagnificationGesture()
                            .updating($magnifyBy) { currentState, gestureState, _ in
                                gestureState = currentState
                            }
                            .onEnded { value in
                                scale = min(max(scale * value, 1), 4)
                                if scale == 1 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        offset = .zero
                                    }
                                }
                            }
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if scale > 1 {
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                            }
                            .onEnded { _ in
                                lastOffset = offset
                            }
                    )
                    .gesture(
                        TapGesture(count: 2)
                            .onEnded {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    if scale > 1 {
                                        scale = 1
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2
                                    }
                                }
                            }
                    )
            }
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        isPresented = false
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                Spacer()
                
                // Photo info bar
                HStack(spacing: 16) {
                    // Image size info
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .font(.system(size: 14))
                        Text("\(Int(image.size.width)) × \(Int(image.size.height))")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    // Zoom hint
                    if scale == 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "hand.pinch")
                                .font(.system(size: 14))
                            Text("Pinch to zoom")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.5))
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 14))
                            Text("\(Int(scale * 100))%")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .statusBarHidden()
    }
}

