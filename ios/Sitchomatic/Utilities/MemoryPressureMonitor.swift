import Foundation
import UIKit

@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()

    private var observers: [() -> Void] = []
    private var isRegistered: Bool = false

    func register() {
        guard !isRegistered else { return }
        isRegistered = true
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleMemoryWarning()
        }
    }

    func onMemoryWarning(_ handler: @escaping @MainActor () -> Void) {
        observers.append(handler)
    }

    private func handleMemoryWarning() {
        DebugLogger.shared.log("MEMORY WARNING received — triggering cleanup handlers (\(observers.count) registered)", category: .system, level: .warning)
        for handler in observers {
            handler()
        }
    }
}
