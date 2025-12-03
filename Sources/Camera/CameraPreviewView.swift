import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var cameraController: CameraController
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        
        let previewLayer = cameraController.previewLayer
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            let bounds = uiView.bounds
            let width = bounds.width
            let targetHeight = width * cameraController.aspectRatio.multiplier
            let height = min(targetHeight, bounds.height)
            let yOffset = (bounds.height - height) / 2
            
            cameraController.previewLayer.frame = CGRect(
                x: 0,
                y: yOffset,
                width: width,
                height: height
            )
        }
    }
}
