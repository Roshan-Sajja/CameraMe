import AVFoundation
import Combine
import UIKit

/// Tracks physical device orientation so controls can rotate without changing overall layout.
final class DeviceOrientationManager: ObservableObject {
    @Published private(set) var deviceOrientation: UIDeviceOrientation
    @Published private(set) var videoOrientation: AVCaptureVideoOrientation
    
    private var cancellable: AnyCancellable?
    
    init() {
        let initialOrientation = DeviceOrientationManager.resolvedOrientation(from: UIDevice.current.orientation) ?? .portrait
        deviceOrientation = initialOrientation
        videoOrientation = DeviceOrientationManager.videoOrientation(for: initialOrientation)
        
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        
        cancellable = NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)
            .compactMap { _ in
                DeviceOrientationManager.resolvedOrientation(from: UIDevice.current.orientation)
            }
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] newOrientation in
                guard let self else { return }
                deviceOrientation = newOrientation
                videoOrientation = DeviceOrientationManager.videoOrientation(for: newOrientation)
            }
    }
    
    deinit {
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        cancellable?.cancel()
    }
    
    var rotationDegrees: Double {
        switch deviceOrientation {
        case .landscapeLeft:
            return -90
        case .landscapeRight:
            return 90
        case .portraitUpsideDown:
            return 180
        default:
            return 0
        }
    }
    
    private static func resolvedOrientation(from orientation: UIDeviceOrientation) -> UIDeviceOrientation? {
        switch orientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            return orientation
        default:
            return nil
        }
    }
    
    private static func videoOrientation(for orientation: UIDeviceOrientation) -> AVCaptureVideoOrientation {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}
