# Fix WebView IP Leaks & Network Config Issues

## Summary
The WebViews are currently leaking the real device IP in several scenarios. This plan fixes all the paths where traffic can bypass the proxy/VPN, ensuring WebViews always return a different IP.

---

### **Fix 1: WebView Always Gets a Proxy — Never Bare IP**
- When WireGuard mode is active but the tunnel isn't connected yet, apply a SOCKS5 fallback proxy to the WebView configuration immediately (instead of just firing a background VPN connect and letting the WebView load unprotected)
- When OpenVPN mode is active but no tunnel exists, apply the same SOCKS5 fallback
- If no SOCKS5 fallback is available either, **block the WebView from loading** and return an error to the caller — never silently proceed on real IP

### **Fix 2: Use Correct Target for SOCKS5 Fallback**
- All fallback paths currently hardcode `.joe` when looking for a SOCKS5 proxy — change these to accept and use the actual target (Joe/Ignition/PPSR) so the correct proxy pool is used
- Add a `target` parameter to `configureWKWebView`, `buildURLSessionConfiguration`, and `buildProxiedDataStore`

### **Fix 3: Make `buildProxiedDataStore` Handle All Config Types**
- Currently only handles SOCKS5 and silently ignores WireGuard/OpenVPN — extend it to apply proxy configurations for all modes (using the same WireProxy/SOCKS5 fallback logic as `configureWKWebView`)

### **Fix 4: Prevent Duplicate VPN Connection Attempts**
- Add a guard in `VPNTunnelManager.configureAndConnect` that skips if already connecting/connected to the same config
- Remove the redundant VPN connect triggers from `buildURLSessionConfiguration` and `configureWKWebView` — VPN connection should only be initiated from `nextConfig()` or `DeviceProxyService`

### **Fix 5: WebView Proxy Pre-flight Verification**
- Before loading a WebView through a proxy, do a quick connectivity test (SOCKS5 handshake, ~2 second timeout)
- If the proxy is dead, immediately rotate to the next working proxy before the WebView starts loading
- Log the result for diagnostics

### **Fix 6: Clean Up WebViewPool Dead Code**
- Remove the `available` pool array since WebViews are always created fresh (never reused)
- Simplify to just track `inUse` count for diagnostics
- Ensure `proxyConfigurations` are explicitly cleared on release

### **Fix 7: Fix WireProxy Handoff Double-Finish**
- In `WireProxySOCKS5Handler.handoffToWireProxyBridge()`, remove the premature `tunnelConnectionFinished` call — let the bridge manage the connection lifecycle

### **Fix 8: DeviceProxy Respects Connection Mode Preference**
- Change `resolveNextConfig()` to check the user's unified connection mode preference and select the matching config type first, instead of always prioritizing WireGuard over everything else
