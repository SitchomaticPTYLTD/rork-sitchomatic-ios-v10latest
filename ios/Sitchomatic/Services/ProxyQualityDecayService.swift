import Foundation

@MainActor
class ProxyQualityDecayService {
    static let shared = ProxyQualityDecayService()

    private let logger = DebugLogger.shared
    private let persistKey = "proxy_quality_decay_v1"
    private var proxyScores: [String: DecayingProxyScore] = [:]
    private let decayHalfLifeSeconds: TimeInterval = 1800
    private let maxRecentEntries: Int = 50

    init() {
        loadScores()
    }

    struct DecayingProxyScore {
        var identifier: String
        var successes: [(date: Date, latencyMs: Int)] = []
        var failures: [(date: Date, type: String)] = []
        var totalAttempts: Int = 0
        var lastUpdated: Date = .distantPast

        func weightedSuccessRate(halfLife: TimeInterval) -> Double {
            let now = Date()
            var weightedSuccess = 0.0
            var weightedTotal = 0.0

            for entry in successes.suffix(50) {
                let age = now.timeIntervalSince(entry.date)
                let weight = pow(0.5, age / halfLife)
                weightedSuccess += weight
                weightedTotal += weight
            }

            for entry in failures.suffix(50) {
                let age = now.timeIntervalSince(entry.date)
                let weight = pow(0.5, age / halfLife)
                weightedTotal += weight
            }

            guard weightedTotal > 0 else { return 0.5 }
            return weightedSuccess / weightedTotal
        }

        func weightedLatencyMs(halfLife: TimeInterval) -> Double {
            let now = Date()
            var weightedSum = 0.0
            var weightedCount = 0.0

            for entry in successes.suffix(30) {
                let age = now.timeIntervalSince(entry.date)
                let weight = pow(0.5, age / halfLife)
                weightedSum += Double(entry.latencyMs) * weight
                weightedCount += weight
            }

            return weightedCount > 0 ? weightedSum / weightedCount : 5000
        }

        func compositeScore(halfLife: TimeInterval) -> Double {
            let sr = weightedSuccessRate(halfLife: halfLife)
            let latency = weightedLatencyMs(halfLife: halfLife)
            let latencyScore = max(0, 1.0 - (latency / 15000.0))

            let now = Date()
            var recencyScore = 0.3
            if let lastSuccess = successes.last?.date {
                let ago = now.timeIntervalSince(lastSuccess)
                recencyScore = max(0, 1.0 - (ago / 7200.0))
            }

            let recentFailTypes = failures.suffix(5).map { $0.type }
            let consecutiveFailPenalty = recentFailTypes.allSatisfy({ !$0.isEmpty }) && recentFailTypes.count >= 3 ? 0.3 : 1.0

            return (sr * 0.45 + latencyScore * 0.30 + recencyScore * 0.25) * consecutiveFailPenalty
        }
    }

    func recordSuccess(proxyId: String, latencyMs: Int) {
        var score = proxyScores[proxyId] ?? DecayingProxyScore(identifier: proxyId)
        score.successes.append((Date(), latencyMs))
        score.totalAttempts += 1
        score.lastUpdated = Date()
        trimEntries(&score)
        proxyScores[proxyId] = score
        persistScores()
    }

    func recordFailure(proxyId: String, failureType: String) {
        var score = proxyScores[proxyId] ?? DecayingProxyScore(identifier: proxyId)
        score.failures.append((Date(), failureType))
        score.totalAttempts += 1
        score.lastUpdated = Date()
        trimEntries(&score)
        proxyScores[proxyId] = score
        persistScores()
    }

    func scoreFor(proxyId: String) -> Double {
        proxyScores[proxyId]?.compositeScore(halfLife: decayHalfLifeSeconds) ?? 0.5
    }

    func selectBestProxy(from proxyIds: [String]) -> String? {
        guard !proxyIds.isEmpty else { return nil }
        if proxyIds.count == 1 { return proxyIds.first }

        let scored = proxyIds.map { id -> (String, Double) in
            (id, scoreFor(proxyId: id))
        }

        let totalWeight = scored.reduce(0.0) { $0 + max($1.1, 0.05) }
        var random = Double.random(in: 0..<totalWeight)

        for (id, weight) in scored {
            random -= max(weight, 0.05)
            if random <= 0 { return id }
        }

        return proxyIds.last
    }

    func allScores() -> [(id: String, score: Double, attempts: Int, successRate: Int, avgLatency: Int)] {
        proxyScores.map { id, score in
            (id, score.compositeScore(halfLife: decayHalfLifeSeconds), score.totalAttempts, Int(score.weightedSuccessRate(halfLife: decayHalfLifeSeconds) * 100), Int(score.weightedLatencyMs(halfLife: decayHalfLifeSeconds)))
        }.sorted { $0.1 > $1.1 }
    }

    func isDemoted(proxyId: String, threshold: Double = 0.2) -> Bool {
        scoreFor(proxyId: proxyId) < threshold
    }

    func resetAll() {
        proxyScores.removeAll()
        persistScores()
        logger.log("ProxyQualityDecay: all scores reset", category: .proxy, level: .info)
    }

    private func trimEntries(_ score: inout DecayingProxyScore) {
        if score.successes.count > maxRecentEntries {
            score.successes = Array(score.successes.suffix(maxRecentEntries))
        }
        if score.failures.count > maxRecentEntries {
            score.failures = Array(score.failures.suffix(maxRecentEntries))
        }
    }

    private func persistScores() {
        var dict: [String: [String: Any]] = [:]
        for (id, score) in proxyScores {
            dict[id] = [
                "totalAttempts": score.totalAttempts,
                "lastUpdated": score.lastUpdated.timeIntervalSince1970,
            ]
        }
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: persistKey)
        }
    }

    private func loadScores() {
        guard let data = UserDefaults.standard.data(forKey: persistKey),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return }
        for (id, values) in dict {
            var score = DecayingProxyScore(identifier: id)
            score.totalAttempts = values["totalAttempts"] as? Int ?? 0
            if let ts = values["lastUpdated"] as? TimeInterval {
                score.lastUpdated = Date(timeIntervalSince1970: ts)
            }
            proxyScores[id] = score
        }
    }
}
