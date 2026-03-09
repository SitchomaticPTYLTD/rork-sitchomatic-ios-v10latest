# 3-Stage VPN & Proxy Overhaul — Make Every WebView Show the VPN IP

## Problem
Currently, WireGuard and OpenVPN configs are assigned to WebViews but **no actual VPN tunnel is established**. The PAC script injection via JavaScript doesn't route WKWebView traffic through proxies — it just sets a JS variable. Every WebView still shows your real IP.

---

## Stage 1 — Fix SOCKS5 Proxy Routing (Immediate Impact)

**What changes:**
- Replace the broken PAC/JavaScript proxy injection with the proper iOS `ProxyConfiguration` API
- Every WKWebView will use `WKWebsiteDataStore.proxyConfigurations` with SOCKS5 proxy settings
- This is the official Apple API (iOS 17+) that **actually routes** all WebView network traffic through the proxy
- When a SOCKS5 proxy is assigned, the WebView will show the **proxy IP** — not your real IP

**Features:**
- All WebView sessions (login tests, IP score tests, split tests) will use real SOCKS5 routing
- URLSession requests also properly configured with SOCKS5 proxy dictionaries (already partially working)
- The IP Score test page will show the actual proxy IP address
- Unified mode (DeviceProxyService) will apply the same proxy to every WebView simultaneously
- Fallback to direct connection if no proxy is available

---

## Stage 2 — On-Device Local Proxy Server (Wireproxy Concept)

**What changes:**
- Build a local SOCKS5 proxy server running inside the app on `localhost`
- Uses Apple's Network framework (`NWListener`) — no external dependencies
- Acts as a proxy forwarder: all WebViews connect to `localhost:PORT`, which forwards traffic through the selected upstream SOCKS5 proxy
- This is the on-device equivalent of wireproxy — a local intermediary that all app traffic routes through

**Features:**
- Single unified proxy endpoint for the entire app (`localhost:PORT`)
- Upstream proxy rotation happens transparently — change the upstream, all WebViews immediately use the new IP
- No need to reconfigure or recreate WebViews when rotating proxies
- Connection pooling and keep-alive management
- Automatic health monitoring — if the upstream proxy dies, auto-rotate to the next one
- Support for proxy chaining (local → upstream SOCKS5 → internet)
- Status dashboard showing active connections, bytes transferred, upstream health

---

## Stage 3 — Device-Wide VPN Tunnel (NetworkExtension)

**What changes:**
- Add a Network Extension target with a Packet Tunnel Provider
- Implements a real VPN tunnel using `NEPacketTunnelProvider`
- When active, **ALL device traffic** (every WebView, every URL request, everything) routes through the VPN
- Supports WireGuard protocol via the tunnel provider
- Managed from the main app via `NETunnelProviderManager`

**Features:**
- True device-wide VPN — every single network request uses the VPN IP
- WireGuard tunnel support using your existing WireGuard configs
- Start/stop VPN from within the app
- Auto-rotation: disconnect and reconnect with a different WireGuard server on schedule
- VPN status indicator in the app (connected/disconnected/rotating)
- Fallback chain: WireGuard tunnel → SOCKS5 proxy → direct
- Integration with existing DeviceProxyService rotation timers and batch triggers
- Works on real devices (Network Extensions require physical hardware — shows placeholder in simulator)

**Note:** Stage 3 requires the Network Extension entitlement from Apple and only works on real devices. The app will detect this and fall back to Stage 2 (local proxy) or Stage 1 (direct SOCKS5) automatically.

---

## Summary

| Stage | What It Does | Works In Simulator? |
|-------|-------------|-------------------|
| 1 | Fix SOCKS5 → WebView routing with proper iOS API | ✅ Yes |
| 2 | Local proxy server for unified app-wide routing | ✅ Yes |
| 3 | Device-wide VPN tunnel via NetworkExtension | ❌ Real device only |

Say **"yes"**, **"continue"**, or **"analysis"** after each stage to proceed to the next one.
