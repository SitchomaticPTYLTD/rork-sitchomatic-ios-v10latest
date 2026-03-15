import Foundation
import UIKit

@MainActor
final class MemoryPressureMonitor {
    static let shared = MemoryPressureMonitor()

    private var observers: [() -> Void] = []
    private var isRegistered: Bool = false
    private var proactivePollingTask: Task<Void, Never>?
    private var consecutiveHighMemory: Int = 0
    private let warningThresholdMB: Int = 300
    private let criticalThresholdMB: Int = 450

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
        startProactivePolling()
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

    private func startProactivePolling() {
        proactivePollingTask?.cancel()
        proactivePollingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard !Task.isCancelled, let self else { return }
                let mb = CrashProtectionService.shared.currentMemoryUsageMB()
                if mb > self.criticalThresholdMB {
                    self.consecutiveHighMemory += 1
                    if self.consecutiveHighMemory >= 2 {
                        DebugLogger.shared.log("MemoryMonitor: proactive trigger — \(mb)MB for \(self.consecutiveHighMemory) consecutive checks", category: .system, level: .warning)
                        self.handleMemoryWarning()
                    }
                } else if mb > self.warningThresholdMB {
                    self.consecutiveHighMemory += 1
                } else {
                    self.consecutiveHighMemory = 0
                }
            }
        }
    }
}
