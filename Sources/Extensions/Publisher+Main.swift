import Combine
import Foundation

extension Publisher {
    /// Helper to ensure downstream receives values on the main queue.
    func receiveOnMain() -> Publishers.ReceiveOn<Self, DispatchQueue> {
        receive(on: DispatchQueue.main)
    }
}
