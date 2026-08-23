import Foundation
import CoreMotion

@MainActor
final class StepCounter: ObservableObject {
    @Published var steps: Int = 0
    @Published var unavailable = false
    private let pedometer = CMPedometer()

    func start() {
        guard CMPedometer.isStepCountingAvailable() else { unavailable = true; return }
        pedometer.startUpdates(from: Date()) { [weak self] data, error in
            Task { @MainActor in
                if error != nil { self?.unavailable = true; return }
                self?.steps = data?.numberOfSteps.intValue ?? 0
            }
        }
    }

    func stop() { pedometer.stopUpdates() }
}
