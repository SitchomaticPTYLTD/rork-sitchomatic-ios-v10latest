import Foundation

@MainActor
class HostCircuitBreakerService {
    static let shared = HostCircuitBreakerService()

    private let logger = DebugLogger.shared
    private var hostStates: [String: CircuitState] = [:]

    private let failureThreshold: Int = 3
    private let cooldownSeconds: TimeInterval = 30
    private let halfOpenMaxProbes: Int = 2
    private let timeoutWeight: Int = 2
    private let rateLimitWeight: Int = 3

    nonisolated enum BreakerStatus: String, Sendable {
        case closed
        case open
        case halfOpen
    }

    private struct CircuitState {
        var status: BreakerStatus = .closed
        var failureCount: Int = 0
        var weightedFailureScore: Int = 0
        var openedAt: Date?
        var halfOpenProbes: Int = 0
        var lastFailureType: FailureType?

        var isTripped: Bool {
            switch status {
            case .open:
                return true
            case .halfOpen:
                return false
            case .closed:
                return false
            }
        }
    }

    nonisolated enum FailureType: String, Sendable {
        case timeout
        case connectionError
        case rateLimited429
        case serverError5xx
        case blankPage
        case generic
    }

    func shouldAllow(host: String, path: String? = nil) -> Bool {
        let key = circuitKey(host: host, path: path)
        guard var state = hostStates[key] else { return true }

        switch state.status {
        case .closed:
            return true
        case .open:
            if let opened = state.openedAt, Date().timeIntervalSince(opened) >= cooldownSeconds {
                state.status = .halfOpen
                state.halfOpenProbes = 0
                hostStates[key] = state
                logger.log("CircuitBreaker: \(key) → HALF-OPEN (cooldown expired)", category: .network, level: .info)
                return true
            }
            return false
        case .halfOpen:
            if state.halfOpenProbes < halfOpenMaxProbes {
                return true
            }
            return false
        }
    }

    func recordFailure(host: String, path: String? = nil, type: FailureType) {
        let key = circuitKey(host: host, path: path)
        var state = hostStates[key] ?? CircuitState()

        let weight: Int
        switch type {
        case .timeout: weight = timeoutWeight
        case .rateLimited429: weight = rateLimitWeight
        case .serverError5xx: weight = 2
        case .blankPage: weight = 1
        case .connectionError: weight = 2
        case .generic: weight = 1
        }

        state.failureCount += 1
        state.weightedFailureScore += weight
        state.lastFailureType = type

        if state.status == .halfOpen {
            state.status = .open
            state.openedAt = Date()
            state.halfOpenProbes = 0
            logger.log("CircuitBreaker: \(key) HALF-OPEN → OPEN (probe failed: \(type.rawValue))", category: .network, level: .warning)
        } else if state.weightedFailureScore >= failureThreshold * 2 {
            state.status = .open
            state.openedAt = Date()
            logger.log("CircuitBreaker: \(key) TRIPPED OPEN — weighted score \(state.weightedFailureScore), \(state.failureCount) failures, last: \(type.rawValue)", category: .network, level: .critical)
        }

        hostStates[key] = state
    }

    func recordSuccess(host: String, path: String? = nil) {
        let key = circuitKey(host: host, path: path)
        guard var state = hostStates[key] else { return }

        if state.status == .halfOpen {
            state.halfOpenProbes += 1
            if state.halfOpenProbes >= halfOpenMaxProbes {
                state.status = .closed
                state.failureCount = 0
                state.weightedFailureScore = 0
                state.openedAt = nil
                state.halfOpenProbes = 0
                logger.log("CircuitBreaker: \(key) HALF-OPEN → CLOSED (probes succeeded)", category: .network, level: .success)
            }
        } else {
            state.failureCount = max(0, state.failureCount - 1)
            state.weightedFailureScore = max(0, state.weightedFailureScore - 1)
        }

        hostStates[key] = state
    }

    func status(for host: String, path: String? = nil) -> BreakerStatus {
        let key = circuitKey(host: host, path: path)
        return hostStates[key]?.status ?? .closed
    }

    func cooldownRemaining(host: String, path: String? = nil) -> TimeInterval {
        let key = circuitKey(host: host, path: path)
        guard let state = hostStates[key], state.status == .open, let opened = state.openedAt else { return 0 }
        return max(0, cooldownSeconds - Date().timeIntervalSince(opened))
    }

    func allOpenCircuits() -> [(key: String, failureCount: Int, remainingSeconds: Int, lastFailure: String)] {
        hostStates.compactMap { key, state in
            guard state.status == .open || state.status == .halfOpen else { return nil }
            let remaining = state.openedAt.map { Int(max(0, cooldownSeconds - Date().timeIntervalSince($0))) } ?? 0
            return (key, state.failureCount, remaining, state.lastFailureType?.rawValue ?? "unknown")
        }.sorted { $0.remainingSeconds > $1.remainingSeconds }
    }

    func resetCircuit(host: String, path: String? = nil) {
        let key = circuitKey(host: host, path: path)
        hostStates.removeValue(forKey: key)
        logger.log("CircuitBreaker: \(key) manually RESET", category: .network, level: .info)
    }

    func resetAll() {
        hostStates.removeAll()
        logger.log("CircuitBreaker: all circuits RESET", category: .network, level: .info)
    }

    private func circuitKey(host: String, path: String?) -> String {
        if let path, !path.isEmpty {
            return "\(host)\(path)"
        }
        return host
    }
}
