import Foundation
@preconcurrency import NetworkExtension
import Observation

nonisolated enum VPNTunnelStatus: String, Sendable {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case disconnecting = "Disconnecting"
    case reasserting = "Reasserting"
    case invalid = "Invalid"
    case configuring = "Configuring"
    case error = "Error"
}

@Observable
@MainActor
class VPNTunnelManager {
    static let shared = VPNTunnelManager()

    private(set) var status: VPNTunnelStatus = .disconnected
    private(set) var connectedSince: Date?
    private(set) var activeConfigName: String?
    private(set) var lastError: String?
    private(set) var isSupported: Bool = false
    private(set) var statusDetail: String = "Not configured"

    var autoReconnect: Bool = true {
        didSet { persistSettings() }
    }
    var vpnEnabled: Bool = false {
        didSet { persistSettings() }
    }

    private var manager: NETunnelProviderManager?
    private var statusObserver: Any?
    private let logger = DebugLogger.shared
    private let settingsKey = "vpn_tunnel_settings_v1"
    private let providerBundleID: String

    init() {
        let mainBundleID = Bundle.main.bundleIdentifier ?? "app.rork.ve5l1conjgc135kle8kuj"
        providerBundleID = "\(mainBundleID).PacketTunnel"
        loadSettings()
        checkSupport()
    }

    private func checkSupport() {
        #if targetEnvironment(simulator)
        isSupported = false
        statusDetail = "VPN requires a real device"
        #else
        isSupported = true
        statusDetail = "Ready"
        #endif
    }

    func loadExistingManager() async {
        do {
            let managers = try await NETunnelProviderManager.loadAllFromPreferences()
            if let existing = managers.first(where: {
                ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleID
            }) {
                self.manager = existing
                updateStatusFromManager(existing)
                observeStatus(existing)
                logger.log("VPNTunnel: loaded existing manager — \(existing.localizedDescription ?? "unnamed")", category: .vpn, level: .info)
            } else if let first = managers.first {
                self.manager = first
                updateStatusFromManager(first)
                observeStatus(first)
                logger.log("VPNTunnel: loaded first available manager", category: .vpn, level: .info)
            } else {
                statusDetail = "No VPN configuration"
                logger.log("VPNTunnel: no existing managers found", category: .vpn, level: .info)
            }
        } catch {
            lastError = error.localizedDescription
            logger.log("VPNTunnel: failed to load managers — \(error)", category: .vpn, level: .error)
        }
    }

    func configureAndConnect(with wgConfig: WireGuardConfig) async {
        guard isSupported else {
            lastError = "VPN not supported on simulator"
            status = .error
            return
        }

        status = .configuring
        activeConfigName = wgConfig.fileName
        statusDetail = "Configuring \(wgConfig.fileName)..."

        do {
            let tunnelManager: NETunnelProviderManager
            if let existing = manager {
                tunnelManager = existing
            } else {
                tunnelManager = NETunnelProviderManager()
            }

            let proto = NETunnelProviderProtocol()
            proto.providerBundleIdentifier = providerBundleID
            proto.serverAddress = wgConfig.endpointHost
            proto.providerConfiguration = [
                "wgQuickConfig": wgConfig.rawContent
            ]

            tunnelManager.protocolConfiguration = proto
            tunnelManager.localizedDescription = "WireGuard — \(wgConfig.serverName)"
            tunnelManager.isEnabled = true

            try await tunnelManager.saveToPreferences()
            try await tunnelManager.loadFromPreferences()

            self.manager = tunnelManager
            observeStatus(tunnelManager)

            try tunnelManager.connection.startVPNTunnel(options: [
                "activationAttemptId": UUID().uuidString as NSString
            ])

            status = .connecting
            statusDetail = "Connecting to \(wgConfig.serverName)..."
            logger.log("VPNTunnel: starting tunnel → \(wgConfig.displayString)", category: .vpn, level: .info)

        } catch {
            status = .error
            lastError = error.localizedDescription
            statusDetail = "Error: \(error.localizedDescription)"
            logger.log("VPNTunnel: failed to configure/connect — \(error)", category: .vpn, level: .error)
        }
    }

    func disconnect() {
        guard let manager else {
            status = .disconnected
            return
        }

        status = .disconnecting
        statusDetail = "Disconnecting..."
        manager.connection.stopVPNTunnel()
        logger.log("VPNTunnel: disconnect requested", category: .vpn, level: .info)
    }

    func reconnectWithConfig(_ wgConfig: WireGuardConfig) async {
        disconnect()
        try? await Task.sleep(for: .seconds(1))
        await configureAndConnect(with: wgConfig)
    }

    func removeConfiguration() async {
        guard let manager else { return }
        do {
            try await manager.removeFromPreferences()
            self.manager = nil
            status = .disconnected
            activeConfigName = nil
            connectedSince = nil
            statusDetail = "Configuration removed"
            logger.log("VPNTunnel: configuration removed", category: .vpn, level: .info)
        } catch {
            lastError = error.localizedDescription
            logger.log("VPNTunnel: failed to remove config — \(error)", category: .vpn, level: .error)
        }
    }

    var isConnected: Bool {
        status == .connected
    }

    var isActive: Bool {
        status == .connected || status == .connecting || status == .reasserting
    }

    private func observeStatus(_ manager: NETunnelProviderManager) {
        if let existing = statusObserver {
            NotificationCenter.default.removeObserver(existing)
        }

        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateStatusFromManager(manager)
            }
        }
    }

    private func updateStatusFromManager(_ manager: NETunnelProviderManager) {
        let vpnStatus = manager.connection.status
        switch vpnStatus {
        case .invalid:
            status = .invalid
            statusDetail = "Invalid configuration"
            connectedSince = nil
        case .disconnected:
            status = .disconnected
            statusDetail = "Disconnected"
            connectedSince = nil
        case .connecting:
            status = .connecting
            statusDetail = "Connecting..."
        case .connected:
            status = .connected
            connectedSince = manager.connection.connectedDate
            statusDetail = "Connected to \(activeConfigName ?? "VPN")"
            logger.log("VPNTunnel: CONNECTED — \(activeConfigName ?? "unknown")", category: .vpn, level: .success)
        case .reasserting:
            status = .reasserting
            statusDetail = "Reasserting connection..."
        case .disconnecting:
            status = .disconnecting
            statusDetail = "Disconnecting..."
        @unknown default:
            status = .disconnected
            statusDetail = "Unknown state"
        }
    }

    var uptimeString: String {
        guard let since = connectedSince else { return "--:--" }
        let elapsed = Int(Date().timeIntervalSince(since))
        let hrs = elapsed / 3600
        let mins = (elapsed % 3600) / 60
        let secs = elapsed % 60
        if hrs > 0 {
            return String(format: "%d:%02d:%02d", hrs, mins, secs)
        }
        return String(format: "%d:%02d", mins, secs)
    }

    private func persistSettings() {
        let dict: [String: Any] = [
            "autoReconnect": autoReconnect,
            "vpnEnabled": vpnEnabled,
        ]
        UserDefaults.standard.set(dict, forKey: settingsKey)
    }

    private func loadSettings() {
        guard let dict = UserDefaults.standard.dictionary(forKey: settingsKey) else { return }
        if let ar = dict["autoReconnect"] as? Bool { autoReconnect = ar }
        if let ve = dict["vpnEnabled"] as? Bool { vpnEnabled = ve }
    }

    nonisolated deinit {
        let obs = MainActor.assumeIsolated { statusObserver }
        if let obs {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}
