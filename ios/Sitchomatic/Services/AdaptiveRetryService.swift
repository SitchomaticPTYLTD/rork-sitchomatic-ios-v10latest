import Foundation

@MainActor
class AdaptiveRetryService {
    static let shared = AdaptiveRetryService()

    private let logger = DebugLogger.shared

    nonisolated enum FailureCategory: String, Sendable {
        case timeout
        case connectionFailure
        case fieldDetectionMiss
        case submitNoOp
        case disabledAccount
        case rateLimited
        case blankPage
        case captcha
        case unknown
    }

    nonisolated struct RetryPolicy: Sendable {
        let maxRetries: Int
        let baseDelayMs: Int
        let backoffMultiplier: Double
        let shouldRotateURL: Bool
        let shouldRotateProxy: Bool
        let shouldRecycleWebView: Bool
        let shouldSwitchPattern: Bool
    }

    func policyFor(_ category: FailureCategory) -> RetryPolicy {
        switch category {
        case .timeout:
            return RetryPolicy(
                maxRetries: 2,
                baseDelayMs: 2000,
                backoffMultiplier: 2.0,
                shouldRotateURL: true,
                shouldRotateProxy: false,
                shouldRecycleWebView: true,
                shouldSwitchPattern: false
            )
        case .connectionFailure:
            return RetryPolicy(
                maxRetries: 3,
                baseDelayMs: 1500,
                backoffMultiplier: 1.5,
                shouldRotateURL: true,
                shouldRotateProxy: true,
                shouldRecycleWebView: true,
                shouldSwitchPattern: false
            )
        case .fieldDetectionMiss:
            return RetryPolicy(
                maxRetries: 2,
                baseDelayMs: 1000,
                backoffMultiplier: 1.5,
                shouldRotateURL: false,
                shouldRotateProxy: false,
                shouldRecycleWebView: false,
                shouldSwitchPattern: true
            )
        case .submitNoOp:
            return RetryPolicy(
                maxRetries: 3,
                baseDelayMs: 800,
                backoffMultiplier: 1.5,
                shouldRotateURL: false,
                shouldRotateProxy: false,
                shouldRecycleWebView: false,
                shouldSwitchPattern: true
            )
        case .disabledAccount:
            return RetryPolicy(
                maxRetries: 0,
                baseDelayMs: 0,
                backoffMultiplier: 1.0,
                shouldRotateURL: false,
                shouldRotateProxy: false,
                shouldRecycleWebView: false,
                shouldSwitchPattern: false
            )
        case .rateLimited:
            return RetryPolicy(
                maxRetries: 2,
                baseDelayMs: 15000,
                backoffMultiplier: 2.0,
                shouldRotateURL: true,
                shouldRotateProxy: true,
                shouldRecycleWebView: true,
                shouldSwitchPattern: false
            )
        case .blankPage:
            return RetryPolicy(
                maxRetries: 2,
                baseDelayMs: 3000,
                backoffMultiplier: 2.0,
                shouldRotateURL: true,
                shouldRotateProxy: false,
                shouldRecycleWebView: true,
                shouldSwitchPattern: false
            )
        case .captcha:
            return RetryPolicy(
                maxRetries: 1,
                baseDelayMs: 10000,
                backoffMultiplier: 2.0,
                shouldRotateURL: true,
                shouldRotateProxy: true,
                shouldRecycleWebView: true,
                shouldSwitchPattern: false
            )
        case .unknown:
            return RetryPolicy(
                maxRetries: 1,
                baseDelayMs: 2000,
                backoffMultiplier: 1.5,
                shouldRotateURL: false,
                shouldRotateProxy: false,
                shouldRecycleWebView: false,
                shouldSwitchPattern: true
            )
        }
    }

    func delayForRetry(policy: RetryPolicy, attempt: Int) -> Int {
        let delay = Double(policy.baseDelayMs) * pow(policy.backoffMultiplier, Double(attempt))
        let jitter = Double.random(in: 0.0...0.3) * delay
        return Int(delay + jitter)
    }

    func categorizeOutcome(_ outcome: LoginOutcome, challengeType: ChallengePageClassifier.ChallengeType? = nil, fieldDetectionFailed: Bool = false, submitFailed: Bool = false) -> FailureCategory {
        if let challenge = challengeType {
            switch challenge {
            case .rateLimit: return .rateLimited
            case .captcha, .cloudflareChallenge: return .captcha
            case .temporaryBlock: return .rateLimited
            case .accountDisabled: return .disabledAccount
            case .maintenance: return .connectionFailure
            case .jsFailed: return .blankPage
            case .none, .unknown: break
            }
        }

        switch outcome {
        case .timeout: return .timeout
        case .connectionFailure: return fieldDetectionFailed ? .fieldDetectionMiss : .connectionFailure
        case .permDisabled, .tempDisabled: return .disabledAccount
        case .redBannerError: return .rateLimited
        case .smsDetected: return .rateLimited
        case .noAcc:
            if submitFailed { return .submitNoOp }
            return .unknown
        case .unsure:
            if submitFailed { return .submitNoOp }
            if fieldDetectionFailed { return .fieldDetectionMiss }
            return .unknown
        case .success: return .unknown
        }
    }

    func shouldRetry(category: FailureCategory, currentAttempt: Int) -> Bool {
        let policy = policyFor(category)
        return currentAttempt < policy.maxRetries
    }

    func logRetryDecision(category: FailureCategory, attempt: Int, sessionId: String) {
        let policy = policyFor(category)
        let willRetry = attempt < policy.maxRetries
        let delay = willRetry ? delayForRetry(policy: policy, attempt: attempt) : 0
        logger.log("AdaptiveRetry: \(category.rawValue) attempt \(attempt)/\(policy.maxRetries) — \(willRetry ? "retrying in \(delay)ms" : "NO MORE RETRIES") rotateURL=\(policy.shouldRotateURL) rotateProxy=\(policy.shouldRotateProxy) recycleWV=\(policy.shouldRecycleWebView) switchPattern=\(policy.shouldSwitchPattern)", category: .automation, level: willRetry ? .info : .warning, sessionId: sessionId)
    }
}
