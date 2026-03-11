# Combine WireGuard and WireProxy into a single unified mode

## What's changing

WireGuard mode and WireProxy are doing the same thing — tunneling traffic through WireGuard configs. The current setup has two separate toggles and duplicate code paths that make things confusing and fragile. This plan merges them into one clean "WireGuard" mode that always uses WireProxy (the userspace tunnel that actually works).

### Changes

**1. Remove the separate VPN Tunnel toggle**
- The `vpnTunnelEnabled` toggle in Device Network Settings will be removed — it relies on a system VPN extension that isn't built
- All WireGuard traffic will use WireProxy as the single tunnel mechanism
- The `wireProxyTunnelEnabled` toggle becomes the default behavior when WireGuard mode is active — no separate toggle needed

**2. Simplify DeviceProxyService**
- When WireGuard mode is active and a WG config is selected, WireProxy starts automatically
- No more choosing between "WireProxy tunnel" vs "VPN tunnel" — it's just "WireGuard" and it uses WireProxy under the hood
- The WireProxy dashboard, stats, reconnect, and rotation features all stay as-is

**3. Simplify NetworkSessionFactory**
- Remove the dead VPN tunnel check paths in the `.wireguard` case — WireProxy is always the mechanism
- When `.wireGuardDNS` config is resolved, it always routes through WireProxy's local SOCKS5 proxy
- Fallback to SOCKS5 proxies still works if WireProxy fails to connect

**4. Clean up the UI**
- Device Network Settings: Remove the separate "VPN Tunnel" section
- The WireProxy status/dashboard remains but is now simply called "WireGuard Tunnel" in the UI
- One toggle: WireGuard mode on/off. When on, WireProxy starts. When off, it stops.

**5. Keep VPNTunnelManager as infrastructure**
- The VPNTunnelManager code stays in the codebase (it's used for endpoint reachability testing)
- It just won't be used as a traffic routing mechanism anymore
