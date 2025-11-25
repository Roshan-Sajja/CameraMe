import AVFoundation
import Combine

/// Placeholder camera session wrapper. The real implementation will own
/// `AVCaptureSession`, provide a preview layer, and expose capture APIs.
final class CameraController: NSObject, ObservableObject {
    enum ActiveCamera {
        case front
        case back

        mutating func toggle() {
            self = self == .front ? .back : .front
        }
    }

    @Published private(set) var isSessionRunning = false
    @Published private(set) var activeCamera: ActiveCamera = .front

    private let session = AVCaptureSession()

    override init() {
        super.init()
    }

    func configureSession() throws {
        // TODO: Request camera permission, configure inputs/outputs, and handle errors.
    }

    func startSession() {
        guard !session.isRunning else { return }
        // TODO: Start AVCaptureSession on background queue.
        isSessionRunning = true
    }

    func stopSession() {
        guard session.isRunning else { return }
        // TODO: Stop AVCaptureSession safely.
        isSessionRunning = false
    }

    func toggleCamera() {
        activeCamera.toggle()
        // TODO: Rebuild session inputs for the new position.
    }

    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        // TODO: Use AVCapturePhotoOutput to grab image data and deliver via completion.
        completion(.failure(NSError(domain: "CameraController", code: -1)))
    }
}
