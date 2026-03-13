import Foundation
import Observation
import SwiftUI
import UIKit

nonisolated enum TestDebugPhase: Sendable {
    case setup
    case running
    case results
}

@Observable
@MainActor
class TestDebugViewModel {
    var phase: TestDebugPhase = .setup

    var credentials: [TestDebugCredentialEntry] = [
        TestDebugCredentialEntry(email: "", password: "")
    ]
    var selectedSite: TestDebugSite = .joe
    var sessionCount: TestDebugSessionCount = .twentyFour
    var variationMode: TestDebugVariationMode = .all
    var variationOverrides: TestDebugVariationOverrides = TestDebugVariationOverrides()
    var savedRunSummaries: [TestDebugRunSummary] = []
    var showCompareSheet: Bool = false
    var compareRunA: TestDebugRunSummary?
    var compareRunB: TestDebugRunSummary?

    var sessions: [TestDebugSession] = []
    var currentWave: Int = 0
    var totalWaves: Int = 0
    var isRunning: Bool = false
    var isPaused: Bool = false
    var isStopping: Bool = false

    var selectedSessionForLog: TestDebugSession?
    var showSessionLogSheet: Bool = false
    var isRetryingFailed: Bool = false

    private var batchTask: Task<Void, Never>?
    private let logger = DebugLogger.shared
    private let generator = SettingVariationGenerator.shared
    private let proxyService = ProxyRotationService.shared
    private let urlRotation = LoginURLRotationService.shared
    private var waveStartTimes: [Date] = []

    let waveSize: Int = 6

    var validCredentials: [TestDebugCredentialEntry] {
        credentials.filter(\.isValid)
    }

    var canStart: Bool {
        !validCredentials.isEmpty
    }

    var completedCount: Int {
        sessions.filter { $0.status.isTerminal }.count
    }

    var successCount: Int {
        sessions.filter { $0.status == .success }.count
    }

    var failedCount: Int {
        sessions.filter { $0.status == .failed || $0.status == .connectionFailure }.count
    }

    var unsureCount: Int {
        sessions.filter { $0.status == .unsure || $0.status == .timeout }.count
    }

    var timeoutCount: Int {
        sessions.filter { $0.status == .timeout }.count
    }

    var connectionFailureCount: Int {
        sessions.filter { $0.status == .connectionFailure }.count
    }

    var progress: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(completedCount) / Double(sessions.count)
    }

    var estimatedTimeRemaining: String? {
        guard completedCount > 0, completedCount < sessions.count else { return nil }
        let completedDurations = sessions.compactMap { s -> TimeInterval? in
            guard s.status.isTerminal, let d = s.duration else { return nil }
            return d
        }
        guard !completedDurations.isEmpty else { return nil }
        let avgDuration = completedDurations.reduce(0, +) / Double(completedDurations.count)
        let remaining = sessions.count - completedCount
        let wavesLeft = Int(ceil(Double(remaining) / Double(waveSize)))
        let etaSeconds = avgDuration * Double(wavesLeft)
        if etaSeconds < 60 {
            return "~\(Int(etaSeconds))s remaining"
        } else {
            let mins = Int(etaSeconds / 60)
            let secs = Int(etaSeconds) % 60
            return "~\(mins)m \(secs)s remaining"
        }
    }

    var retryableSessionCount: Int {
        sessions.filter { $0.status == .failed || $0.status == .connectionFailure || $0.status == .timeout || $0.status == .unsure }.count
    }

    var rankedSessions: [TestDebugSession] {
        sessions.sorted { a, b in
            let aScore = statusScore(a.status)
            let bScore = statusScore(b.status)
            if aScore != bScore { return aScore > bScore }
            let aDur = a.duration ?? .infinity
            let bDur = b.duration ?? .infinity
            return aDur < bDur
        }
    }

    var winningSession: TestDebugSession? {
        rankedSessions.first { $0.status == .success }
    }

    private func statusScore(_ status: TestDebugSessionStatus) -> Int {
        switch status {
        case .success: 100
        case .unsure: 50
        case .timeout: 30
        case .failed: 10
        case .connectionFailure: 5
        case .running: 2
        case .queued: 1
        }
    }

    func addCredentialSlot() {
        guard credentials.count < 3 else { return }
        credentials.append(TestDebugCredentialEntry(email: "", password: ""))
    }

    func removeCredentialSlot(at index: Int) {
        guard credentials.count > 1 else { return }
        credentials.remove(at: index)
    }

    func updateCredential(at index: Int, email: String, password: String) {
        guard index < credentials.count else { return }
        credentials[index] = TestDebugCredentialEntry(email: email, password: password)
    }

    func startTest() {
        guard canStart else { return }

        let totalCount = sessionCount.rawValue
        sessions = generator.generateSessions(count: totalCount, mode: variationMode, site: selectedSite, overrides: variationOverrides)
        totalWaves = Int(ceil(Double(totalCount) / Double(waveSize)))
        currentWave = 0
        isRunning = true
        isPaused = false
        isStopping = false
        phase = .running

        logger.log("TestDebug: Starting \(totalCount) sessions in \(totalWaves) waves of \(waveSize)", category: .login, level: .info)

        batchTask = Task {
            await runWaves()
        }
    }

    func pauseTest() {
        isPaused = true
        logger.log("TestDebug: Paused", category: .login, level: .warning)
    }

    func resumeTest() {
        isPaused = false
        logger.log("TestDebug: Resumed", category: .login, level: .info)
    }

    func stopTest() {
        isStopping = true
        isPaused = false
        logger.log("TestDebug: Stopping after current wave", category: .login, level: .warning)
    }

    func reset() {
        batchTask?.cancel()
        batchTask = nil
        sessions = []
        currentWave = 0
        totalWaves = 0
        isRunning = false
        isPaused = false
        isStopping = false
        isRetryingFailed = false
        waveStartTimes = []
        phase = .setup
    }

    func retryFailedSessions() {
        let failedSessions = sessions.filter { !$0.status.isSuccess && $0.status.isTerminal }
        guard !failedSessions.isEmpty, !isRunning else { return }

        for session in failedSessions {
            session.status = .queued
            session.startedAt = nil
            session.completedAt = nil
            session.finalScreenshot = nil
            session.errorMessage = nil
            session.logs.append(PPSRLogEntry(message: "--- RETRY ---", level: .warning))
        }

        totalWaves = Int(ceil(Double(failedSessions.count) / Double(waveSize)))
        currentWave = 0
        isRunning = true
        isPaused = false
        isStopping = false
        isRetryingFailed = true
        phase = .running

        logger.log("TestDebug: Retrying \(failedSessions.count) failed sessions in \(totalWaves) waves", category: .login, level: .info)

        batchTask = Task {
            await runRetryWaves(failedSessions)
        }
    }

    func showSessionLog(_ session: TestDebugSession) {
        selectedSessionForLog = session
        showSessionLogSheet = true
    }

    func saveCurrentRunSummary() {
        guard !sessions.isEmpty else { return }
        let summary = TestDebugRunSummary(
            id: UUID().uuidString,
            date: Date(),
            site: selectedSite.rawValue,
            sessionCount: sessions.count,
            variationMode: variationMode.rawValue,
            successCount: successCount,
            failedCount: failedCount,
            unsureCount: unsureCount,
            timeoutCount: timeoutCount,
            totalDuration: sessions.compactMap(\.duration).reduce(0, +),
            sessionSummaries: sessions.map { s in
                TestDebugSessionSummary(
                    id: s.id,
                    index: s.index,
                    differentiator: s.differentiator,
                    status: s.status.rawValue,
                    duration: s.duration,
                    errorMessage: s.errorMessage
                )
            }
        )
        savedRunSummaries.append(summary)
        if savedRunSummaries.count > 10 {
            savedRunSummaries.removeFirst()
        }
        logger.log("TestDebug: Run saved for comparison (\(savedRunSummaries.count) total)", category: .login, level: .info)
    }

    func generateExportText() -> String {
        var lines: [String] = []
        let dateStr = DateFormatters.timeWithMillis.string(from: Date())
        lines.append("TEST & DEBUG RESULTS — \(dateStr)")
        lines.append("Site: \(selectedSite.rawValue) | Sessions: \(sessions.count) | Mode: \(variationMode.rawValue)")
        lines.append("Success: \(successCount) | Failed: \(failedCount) | Unsure: \(unsureCount) | Timeout: \(timeoutCount)")
        lines.append(String(repeating: "─", count: 60))

        if let winner = winningSession {
            lines.append("🏆 WINNER: #\(winner.index) — \(winner.differentiator) (\(winner.formattedDuration))")
            lines.append(String(repeating: "─", count: 60))
        }

        for (rank, session) in rankedSessions.enumerated() {
            let errStr = session.errorMessage.map { " | Err: \($0)" } ?? ""
            lines.append("#\(rank + 1) [\(session.status.rawValue)] Session \(session.index) — \(session.formattedDuration)\(errStr)")
            lines.append("   \(session.differentiator)")
        }

        return lines.joined(separator: "\n")
    }

    private func runWaves() async {
        let creds = validCredentials
        let targetSite = selectedSite.targetSite
        let proxyTarget: ProxyRotationService.ProxyTarget = selectedSite == .ignition ? .ignition : .joe
        waveStartTimes = []

        for waveIndex in 0..<totalWaves {
            guard !isStopping else { break }

            while isPaused && !isStopping {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !isStopping else { break }

            currentWave = waveIndex + 1
            waveStartTimes.append(Date())
            let startIdx = waveIndex * waveSize
            let endIdx = min(startIdx + waveSize, sessions.count)
            let waveSessions = Array(sessions[startIdx..<endIdx])

            logger.log("TestDebug: Wave \(currentWave)/\(totalWaves) — \(waveSessions.count) sessions", category: .login, level: .info)

            await withTaskGroup(of: Void.self) { group in
                for session in waveSessions {
                    let credIndex = (session.index - 1) % creds.count
                    let cred = creds[credIndex]

                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.runSession(session, credential: cred, targetSite: targetSite, proxyTarget: proxyTarget)
                    }
                }

                await group.waitForAll()
            }

            logger.log("TestDebug: Wave \(currentWave) complete — \(successCount) success, \(failedCount) failed, \(unsureCount) unsure so far", category: .login, level: .info)
        }

        isRunning = false
        isStopping = false
        isRetryingFailed = false
        phase = .results

        logger.log("TestDebug: All waves complete — \(successCount)/\(sessions.count) succeeded", category: .login, level: .success)
        saveCurrentRunSummary()
    }

    private func runRetryWaves(_ retrySessions: [TestDebugSession]) async {
        let creds = validCredentials
        let targetSite = selectedSite.targetSite
        let proxyTarget: ProxyRotationService.ProxyTarget = selectedSite == .ignition ? .ignition : .joe

        let retryWaveCount = Int(ceil(Double(retrySessions.count) / Double(waveSize)))

        for waveIndex in 0..<retryWaveCount {
            guard !isStopping else { break }

            while isPaused && !isStopping {
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard !isStopping else { break }

            currentWave = waveIndex + 1
            let startIdx = waveIndex * waveSize
            let endIdx = min(startIdx + waveSize, retrySessions.count)
            let waveSessions = Array(retrySessions[startIdx..<endIdx])

            logger.log("TestDebug: Retry Wave \(currentWave)/\(retryWaveCount) — \(waveSessions.count) sessions", category: .login, level: .info)

            await withTaskGroup(of: Void.self) { group in
                for session in waveSessions {
                    let credIndex = (session.index - 1) % max(creds.count, 1)
                    let cred = creds[credIndex]

                    group.addTask { [weak self] in
                        guard let self else { return }
                        await self.runSession(session, credential: cred, targetSite: targetSite, proxyTarget: proxyTarget)
                    }
                }

                await group.waitForAll()
            }
        }

        isRunning = false
        isStopping = false
        isRetryingFailed = false
        phase = .results

        logger.log("TestDebug: Retry complete — \(successCount)/\(sessions.count) succeeded", category: .login, level: .success)
    }

    private func runSession(_ session: TestDebugSession, credential: TestDebugCredentialEntry, targetSite: LoginTargetSite, proxyTarget: ProxyRotationService.ProxyTarget) async {
        session.status = .running
        session.startedAt = Date()

        let loginCred = LoginCredential(username: credential.email, password: credential.password)
        let attempt = LoginAttempt(credential: loginCred, sessionIndex: session.index)
        attempt.startedAt = Date()

        let snapshot = session.settingsSnapshot
        var settings = snapshot.toAutomationSettings(base: AutomationSettings())
        settings = settings.normalizedTimeouts()

        let sessionEngine = LoginAutomationEngine()
        sessionEngine.debugMode = false
        sessionEngine.stealthEnabled = snapshot.stealthJSInjection
        sessionEngine.automationSettings = settings
        sessionEngine.proxyTarget = proxyTarget
        sessionEngine.networkConfigOverride = snapshot.buildNetworkConfig(proxyTarget: proxyTarget)

        urlRotation.isIgnitionMode = (selectedSite == .ignition)
        let testURL = urlRotation.nextURL() ?? targetSite.url

        let netConfigLabel = sessionEngine.networkConfigOverride?.label ?? snapshot.connectionMode.rawValue
        session.logs.append(PPSRLogEntry(message: "Config: \(session.differentiator)", level: .info))
        session.logs.append(PPSRLogEntry(message: "URL: \(testURL.host ?? testURL.absoluteString)", level: .info))
        session.logs.append(PPSRLogEntry(message: "Network: \(netConfigLabel)", level: .info))
        session.logs.append(PPSRLogEntry(message: "Pattern: \(snapshot.pattern) | Typing: \(snapshot.typingSpeedMinMs)-\(snapshot.typingSpeedMaxMs)ms | Stealth: \(snapshot.stealthJSInjection)", level: .info))

        session.webViewIndex = snapshot.webViewPoolIndex

        let outcome = await sessionEngine.runLoginTest(attempt, targetURL: testURL, timeout: 90)

        session.completedAt = Date()
        session.errorMessage = attempt.errorMessage

        if let img = attempt.responseSnapshot {
            session.finalScreenshot = img
        }

        switch outcome {
        case .success:
            session.status = .success
        case .noAcc, .permDisabled, .tempDisabled:
            session.status = .failed
        case .unsure, .redBannerError:
            session.status = .unsure
        case .timeout:
            session.status = .timeout
        case .connectionFailure:
            session.status = .connectionFailure
        }

        session.logs.append(PPSRLogEntry(
            message: "Result: \(session.status.rawValue) in \(session.formattedDuration)",
            level: session.status == .success ? .success : (session.status == .unsure || session.status == .timeout ? .warning : .error)
        ))
    }
}
