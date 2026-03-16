import Foundation
import Network
import Observation

nonisolated enum OpenVPNBridgeStatus: String, Sendable {
    case stopped = "Stopped"
    case connecting = "Connecting"
    case established = "Established"
    case reconnecting = "Reconnecting"
    case failed = "Failed"
}

nonisolated struct OpenVPNBridgeStats: Sendable {
    var connectionsServed: Int = 0
    var connectionsFailed: Int = 0
    var bytesUpstream: UInt64 = 0
    var bytesDownstream: UInt64 = 0
    var handshakeLatencyMs: Int = 0
    var lastValidatedAt: Date?
    var consecutiveFailures: Int = 0
}

@Observable
@MainActor
class OpenVPNProxyBridge {
    static let shared = OpenVPNProxyBridge()

    private(set) var status: OpenVPNBridgeStatus = .stopped
    private(set) var stats: OpenVPNBridgeStats = OpenVPNBridgeStats()
    private(set) var lastError: String?
    private(set) var connectedSince: Date?
    private(set) var activeConfig: OpenVPNConfig?
    private(set) var activeSOCKS5Proxy: ProxyConfig?

    private let logger = DebugLogger.shared
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 15
    private var reconnectAttempts: Int = 0
    private let maxReconnectAttempts: Int = 5
    private var isReconnecting: Bool = false

    private let socks5Port: Int = 1080
    private let validationTimeout: TimeInterval = 8

    var isActive: Bool { status == .established }

    func start(with config: OpenVPNConfig) async {
        guard status == .stopped || status == .failed else { return }

        activeConfig = config
        status = .connecting
        lastError = nil
        reconnectAttempts = 0

        let serverHost = resolveServerHost(from: config)
        guard !serverHost.isEmpty else {
            status = .failed
            lastError = "Cannot resolve server hostname from OpenVPN config"
            logger.log("OpenVPNBridge: no hostname in config \(config.fileName)", category: .vpn, level: .error)
            return
        }

        let nordService = NordVPNService.shared
        let username = nordService.serviceUsername
        let password = nordService.servicePassword

        let proxy = ProxyConfig(
            host: serverHost,
            port: socks5Port,
            username: username.isEmpty ? nil : username,
            password: password.isEmpty ? nil : password
        )

        let startTime = CFAbsoluteTimeGetCurrent()
        let (alive, validated) = await validateSOCKS5Endpoint(proxy)
        let latencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

        if alive && validated {
            activeSOCKS5Proxy = proxy
            status = .established
            connectedSince = Date()
            stats.handshakeLatencyMs = latencyMs
            stats.lastValidatedAt = Date()
            stats.consecutiveFailures = 0
            startHealthCheck()
            logger.log("OpenVPNBridge: ESTABLISHED via SOCKS5 → \(serverHost):\(socks5Port) (\(latencyMs)ms)", category: .vpn, level: .success)
            return
        }

        if alive && !validated && !nordService.hasServiceCredentials {
            activeSOCKS5Proxy = proxy
            status = .established
            connectedSince = Date()
            stats.handshakeLatencyMs = latencyMs
            stats.lastValidatedAt = Date()
            stats.consecutiveFailures = 0
            startHealthCheck()
            logger.log("OpenVPNBridge: ESTABLISHED (no-auth) via SOCKS5 → \(serverHost):\(socks5Port) (\(latencyMs)ms)", category: .vpn, level: .success)
            return
        }

        let directTCPAlive = await testDirectTCPConnection(host: serverHost, port: UInt16(config.remotePort))
        if directTCPAlive {
            let altProxy = ProxyConfig(
                host: serverHost,
                port: config.remotePort,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password
            )
            let (altAlive, _) = await validateSOCKS5Endpoint(altProxy)
            if altAlive {
                activeSOCKS5Proxy = altProxy
                status = .established
                connectedSince = Date()
                stats.handshakeLatencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                stats.lastValidatedAt = Date()
                stats.consecutiveFailures = 0
                startHealthCheck()
                logger.log("OpenVPNBridge: ESTABLISHED via alt port \(serverHost):\(config.remotePort)", category: .vpn, level: .success)
                return
            }
        }

        let stationIP = resolveStationIP(from: config)
        if !stationIP.isEmpty && stationIP != serverHost {
            let stationProxy = ProxyConfig(
                host: stationIP,
                port: socks5Port,
                username: username.isEmpty ? nil : username,
                password: password.isEmpty ? nil : password
            )
            let (stationAlive, _) = await validateSOCKS5Endpoint(stationProxy)
            if stationAlive {
                activeSOCKS5Proxy = stationProxy
                status = .established
                connectedSince = Date()
                stats.handshakeLatencyMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
                stats.lastValidatedAt = Date()
                stats.consecutiveFailures = 0
                startHealthCheck()
                logger.log("OpenVPNBridge: ESTABLISHED via station IP \(stationIP):\(socks5Port)", category: .vpn, level: .success)
                return
            }
        }

        status = .failed
        lastError = "SOCKS5 endpoint unreachable on \(serverHost):\(socks5Port)"
        logger.log("OpenVPNBridge: FAILED — all connection strategies exhausted for \(config.fileName)", category: .vpn, level: .error)
    }

    func stop() {
        stopHealthCheck()
        status = .stopped
        connectedSince = nil
        activeConfig = nil
        activeSOCKS5Proxy = nil
        lastError = nil
        isReconnecting = false
        stats = OpenVPNBridgeStats()
        logger.log("OpenVPNBridge: stopped", category: .vpn, level: .info)
    }

    func reconnectPreservingSessions() async {
        guard let config = activeConfig, !isReconnecting else { return }
        isReconnecting = true
        status = .reconnecting

        let preservedStats = stats
        logger.log("OpenVPNBridge: reconnecting with preserved stats", category: .vpn, level: .warning)

        stop()
        stats = preservedStats

        let backoffDelay = min(Double(reconnectAttempts + 1) * 1.5, 8.0)
        try? await Task.sleep(for: .seconds(backoffDelay))

        reconnectAttempts += 1
        isReconnecting = false

        await start(with: config)

        if status != .established && reconnectAttempts < maxReconnectAttempts {
            await reconnectPreservingSessions()
        }
    }

    func recordConnectionServed() {
        stats.connectionsServed += 1
    }

    func recordConnectionFailed() {
        stats.connectionsFailed += 1
        stats.consecutiveFailures += 1
    }

    func recordBytes(up: UInt64, down: UInt64) {
        stats.bytesUpstream += up
        stats.bytesDownstream += down
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        stopHealthCheck()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performHealthCheck()
            }
        }
    }

    private func stopHealthCheck() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func performHealthCheck() async {
        guard status == .established, let proxy = activeSOCKS5Proxy else { return }

        let (alive, _) = await validateSOCKS5Endpoint(proxy)
        if alive {
            stats.lastValidatedAt = Date()
            stats.consecutiveFailures = 0
        } else {
            stats.consecutiveFailures += 1
            logger.log("OpenVPNBridge: health check FAILED (consecutive: \(stats.consecutiveFailures))", category: .vpn, level: .warning)

            if stats.consecutiveFailures >= 3 {
                logger.log("OpenVPNBridge: 3+ consecutive failures — initiating reconnect", category: .vpn, level: .error)
                await reconnectPreservingSessions()
            }
        }
    }

    // MARK: - SOCKS5 Validation

    nonisolated private func validateSOCKS5Endpoint(_ proxy: ProxyConfig) async -> (alive: Bool, validated: Bool) {
        await withCheckedContinuation { continuation in
            let endpoint = NWEndpoint.hostPort(
                host: NWEndpoint.Host(proxy.host),
                port: NWEndpoint.Port(integerLiteral: UInt16(proxy.port))
            )
            let connection = NWConnection(to: endpoint, using: .tcp)
            let queue = DispatchQueue(label: "ovpn-bridge-validate.\(UUID().uuidString.prefix(6))")
            var completed = false

            let timeoutWork = DispatchWorkItem { [weak connection] in
                guard !completed else { return }
                completed = true
                connection?.cancel()
                continuation.resume(returning: (false, false))
            }
            queue.asyncAfter(deadline: .now() + 5, execute: timeoutWork)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    var greeting: Data
                    if proxy.username != nil {
                        greeting = Data([0x05, 0x02, 0x00, 0x02])
                    } else {
                        greeting = Data([0x05, 0x01, 0x00])
                    }

                    connection.send(content: greeting, completion: .contentProcessed { sendError in
                        if sendError != nil {
                            guard !completed else { return }
                            completed = true
                            timeoutWork.cancel()
                            connection.cancel()
                            continuation.resume(returning: (true, false))
                            return
                        }

                        connection.receive(minimumIncompleteLength: 2, maximumLength: 16) { data, _, _, recvError in
                            guard !completed else { return }
                            completed = true
                            timeoutWork.cancel()

                            if recvError != nil {
                                connection.cancel()
                                continuation.resume(returning: (true, false))
                                return
                            }

                            guard let data, data.count >= 2, data[0] == 0x05 else {
                                connection.cancel()
                                continuation.resume(returning: (true, false))
                                return
                            }

                            let authMethod = data[1]

                            if authMethod == 0x02, let username = proxy.username, let password = proxy.password {
                                var authPacket = Data([0x01])
                                let uBytes = Array(username.utf8)
                                authPacket.append(UInt8(uBytes.count))
                                authPacket.append(contentsOf: uBytes)
                                let pBytes = Array(password.utf8)
                                authPacket.append(UInt8(pBytes.count))
                                authPacket.append(contentsOf: pBytes)

                                connection.send(content: authPacket, completion: .contentProcessed { authSendError in
                                    if authSendError != nil {
                                        connection.cancel()
                                        continuation.resume(returning: (true, false))
                                        return
                                    }

                                    connection.receive(minimumIncompleteLength: 2, maximumLength: 4) { authData, _, _, authRecvError in
                                        connection.cancel()
                                        if authRecvError != nil {
                                            continuation.resume(returning: (true, false))
                                            return
                                        }
                                        guard let authData, authData.count >= 2 else {
                                            continuation.resume(returning: (true, false))
                                            return
                                        }
                                        let authSuccess = authData[1] == 0x00
                                        continuation.resume(returning: (true, authSuccess))
                                    }
                                })
                            } else if authMethod == 0x00 {
                                connection.cancel()
                                continuation.resume(returning: (true, true))
                            } else if authMethod == 0xFF {
                                connection.cancel()
                                continuation.resume(returning: (true, false))
                            } else {
                                connection.cancel()
                                continuation.resume(returning: (true, true))
                            }
                        }
                    })

                case .failed:
                    guard !completed else { return }
                    completed = true
                    timeoutWork.cancel()
                    connection.cancel()
                    continuation.resume(returning: (false, false))

                case .cancelled:
                    guard !completed else { return }
                    completed = true
                    timeoutWork.cancel()
                    continuation.resume(returning: (false, false))

                default:
                    break
                }
            }

            connection.start(queue: queue)
        }
    }

    nonisolated private func testDirectTCPConnection(host: String, port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            guard let nwPort = NWEndpoint.Port(rawValue: port) else {
                continuation.resume(returning: false)
                return
            }
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: nwPort,
                using: .tcp
            )
            let queue = DispatchQueue(label: "ovpn-tcp-test.\(UUID().uuidString.prefix(6))")
            var completed = false

            let timeoutWork = DispatchWorkItem { [weak connection] in
                guard !completed else { return }
                completed = true
                connection?.cancel()
                continuation.resume(returning: false)
            }
            queue.asyncAfter(deadline: .now() + 5, execute: timeoutWork)

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    guard !completed else { return }
                    completed = true
                    timeoutWork.cancel()
                    connection.cancel()
                    continuation.resume(returning: true)
                case .failed, .cancelled:
                    guard !completed else { return }
                    completed = true
                    timeoutWork.cancel()
                    continuation.resume(returning: false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    // MARK: - Host Resolution

    private func resolveServerHost(from config: OpenVPNConfig) -> String {
        let host = config.remoteHost
        guard !host.isEmpty else { return "" }

        if host.contains(".nordvpn.com") {
            return host
        }

        if host.rangeOfCharacter(from: CharacterSet.letters) != nil {
            return host
        }

        return host
    }

    private func resolveStationIP(from config: OpenVPNConfig) -> String {
        let lines = config.rawContent.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("remote ") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let addr = parts[1]
                    let isIP = addr.split(separator: ".").count == 4 && addr.allSatisfy { $0.isNumber || $0 == "." }
                    if isIP { return addr }
                }
            }
        }
        return ""
    }

    // MARK: - Display

    var uptimeString: String {
        guard let since = connectedSince else { return "--:--" }
        let elapsed = Int(Date().timeIntervalSince(since))
        let hrs = elapsed / 3600
        let mins = (elapsed % 3600) / 60
        let secs = elapsed % 60
        if hrs > 0 { return String(format: "%d:%02d:%02d", hrs, mins, secs) }
        return String(format: "%d:%02d", mins, secs)
    }

    var statusLabel: String {
        guard let proxy = activeSOCKS5Proxy else { return status.rawValue }
        return "\(status.rawValue) → \(proxy.host):\(proxy.port)"
    }

    var activeProxyLabel: String? {
        guard let proxy = activeSOCKS5Proxy else { return nil }
        return "\(proxy.host):\(proxy.port)"
    }
}
