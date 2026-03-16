# OpenVPN SOCKS5 Bridge — Complete

## Part 1 (Done): Core Engine Rewrite + Connection Handler

- [x] Rewrite `OpenVPNProxyBridge` — NordVPN API lookup + hostname:1080 fallback + region cache + health checks
- [x] Create `OpenVPNSOCKS5Handler` — dedicated per-connection SOCKS5 chaining handler
- [x] Add `nordCountryCode`/`nordCountryId` to `OpenVPNConfig`
- [x] Add `fetchSOCKS5Servers(countryId:)` to `NordVPNService`

## Part 2 (Done): Wiring + Bulletproofing Hybrid Network

- [x] `LocalProxyServer.handleNewConnection` — routes through `OpenVPNSOCKS5Handler` when `openVPNProxyMode` active (parallel to WireProxy path)
- [x] `LocalProxyServer` — added `ovpnConnections` dictionary for OpenVPN handler lifecycle tracking
- [x] `DeviceProxyService.syncOpenVPNProxyBridge` — enables handler mode (no upstream proxy needed, handler chains directly)
- [x] `DeviceProxyService` — added full per-session OpenVPN support mirroring WireGuard (activate/retry/stop/rotate/reconnect)
- [x] `DeviceProxyService.effectiveProxyConfig` — returns local proxy config for per-session OpenVPN mode
- [x] `DeviceProxyService` — updated `ipRoutingMode` didSet, `notifyBatchStart`, `handleUnifiedConnectionModeChange`, `handleProfileSwitch` for OpenVPN
- [x] `NetworkSessionFactory.nextConfig` — picks up per-session tunnel configs before falling through to per-target mode
- [x] `NetworkSessionFactory.resolveEffectiveConfig` — prioritizes handler-based OpenVPN routing over direct bridge proxy
- [x] `HybridNetworkingService.resolveConfig` — OpenVPN method now checks for active bridge+handler before returning raw config
- [x] `HybridNetworkingService.resolveConfig` — WireProxy method now checks for active tunnel before returning raw WG config

## Part 3 (Done): Cross-Pollination + NordServerIntelligence

### NordServerIntelligence (new shared service)
- [x] Load-aware server selection via Nord API `/v1/servers/recommendations`
- [x] Region pool management with per-server health tracking (load, latency, failures, blacklist)
- [x] Health score algorithm: 40% load + 30% failure rate + 20% latency + 10% freshness
- [x] Failed server blacklisting with cooldown TTL (scales with consecutive failures, max 10min)
- [x] Round-robin selection within region pools
- [x] SOCKS5 endpoint resolution with validation (single + batch)
- [x] WireGuard config generation from NordServerHealth entries
- [x] Auto-refresh of stale regions (5min TTL)
- [x] Shared between both OpenVPN and WireProxy protocols

### OpenVPNProxyBridge upgrades (learned from WireProxy)
- [x] Multi-endpoint pool — resolves up to 3 SOCKS5 endpoints upfront via NordIntel, round-robins between them
- [x] Per-endpoint health tracking (consecutive failures, latency, server load, health score)
- [x] Auto-replenishment — when all pool endpoints fail, fetches fresh ones from NordIntel
- [x] Pool-aware health checks — validates all endpoints, promotes healthiest to active
- [x] Extended stats: pool size, active index, pool rotations, server load

### OpenVPNSOCKS5Handler upgrades
- [x] Uses `bridge.nextEndpoint()` for pool round-robin instead of always using `activeSOCKS5Proxy`
- [x] Reports success/failure back to pool with `recordEndpointServed/Failed`
- [x] Failure feedback flows through to NordServerIntelligence for cross-protocol blacklisting

### WireProxyBridge upgrades (learned from OpenVPN)
- [x] Nord API-driven reconnection — when tunnel fails, asks NordIntel for fresh server in same region instead of retrying same config
- [x] Handshake latency tracking (`stats.handshakeLatencyMs`)
- [x] Resolution source tracking (`stats.resolutionSource`)
- [x] Server load tracking via NordIntel (`stats.serverLoad`)
- [x] Consecutive health failure counting (`stats.consecutiveHealthFailures`)
- [x] API reconnect counter (`stats.apiReconnects`)
- [x] Per-slot API-driven reconnection in multi-tunnel mode — replaces failed slots with fresh NordIntel servers
- [x] Nord country ID extraction from WireGuard endpoint hostnames
- [x] Intel success/failure reporting on connect, reconnect, and health check

### DeviceProxyService + HybridNetworkingService wiring
- [x] NordServerIntelligence monitoring starts/stops with unified mode lifecycle
- [x] Intel cleared on profile switch
- [x] HybridNetworkingService reports outcomes to NordIntel for cross-protocol server health

## Architecture

```
App (WKWebView/URLSession)
  → SOCKS5 to LocalProxyServer (127.0.0.1:18080)
    → openVPNProxyMode?
      → OpenVPNSOCKS5Handler (per-connection)
        → pool round-robin selects endpoint from OpenVPNProxyBridge.endpointPool
          → SOCKS5 handshake to NordVPN SOCKS5 endpoint
            → bidirectional relay to target
    → wireProxyMode?
      → WireProxySOCKS5Handler → WireProxy tunnel
    → else
      → LocalProxyConnection → upstream SOCKS5 proxy

NordServerIntelligence (shared)
  → Feeds both OpenVPNProxyBridge and WireProxyBridge
  → Load-aware server selection from Nord API
  → Cross-protocol server health tracking + blacklisting
  → Auto-refresh stale region pools every 5 minutes
```
