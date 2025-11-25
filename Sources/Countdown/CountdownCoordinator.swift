import Combine
import Foundation

/// Simple countdown publisher stub that will later drive both UI animation and audio beeps.
final class CountdownCoordinator {
    struct Tick {
        let current: Int
        let total: Int
        var isFinalTick: Bool { current == total }
    }

    private let totalSeconds: Int
    private var timerCancellable: AnyCancellable?
    private let subject = PassthroughSubject<Tick, Never>()

    init(totalSeconds: Int = 5) {
        self.totalSeconds = totalSeconds
    }

    func start() {
        subject.send(Tick(current: 0, total: totalSeconds))

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .scan(0) { value, _ in value + 1 }
            .prefix(totalSeconds)
            .sink { [weak self] value in
                guard let self else { return }
                subject.send(Tick(current: value, total: totalSeconds))
            }
    }

    func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    var publisher: AnyPublisher<Tick, Never> {
        subject.eraseToAnyPublisher()
    }
}
