# Fix crash loop, change default to DNS, and hide irrelevant tunnel settings

## What's being fixed & improved

### 1. Crash Loop Prevention (Settings Safe Boot)
- **Problem**: Changing certain settings (like switching to WireGuard with no configs) can crash the app on next launch because it tries to re-activate the same bad config on startup, creating an infinite crash loop.
- **Fix**: Add a "safe boot" mechanism that detects repeated crashes (2+ within 30 seconds) and automatically resets network settings to a safe default (DNS mode) before the app finishes launching. This breaks the crash loop.
- The crash counter and timestamps are already tracked — this just adds logic to reset settings when a crash loop is detected.
- After a safe-boot reset, the user sees a brief alert explaining that settings were reset to DNS mode due to repeated crashes.

### 2. Default Connection Mode → DNS (DoH/DoT/HTTPS)
- Change the factory default connection mode from WireGuard to **DNS-over-HTTPS** for all targets (Joe, Ignition, PPSR).
- New users and fresh installs will start on DNS mode instead of WireGuard.
- Existing users' saved settings are not affected — only the default for new/reset installs changes.

### 3. Auto-Hide Irrelevant Tunnel Settings
- **When DNS, Direct, Proxy, or NodeMaven is selected**: All WireGuard tunnel settings, OpenVPN settings, WireProxy server toggle/status, per-session tunnel controls, and tunnel dashboard links are **completely hidden**.
- **When WireGuard, OpenVPN, or Hybrid is selected**: Those tunnel sections remain visible as normal.
- This applies everywhere tunnel settings appear: the Device Network Settings screen, and any connection-mode-specific endpoint config sections.
- The Proxy Manager link, DNS settings, IP routing controls, and other non-tunnel settings remain visible regardless of mode.

### Screens affected
- **Device Network Settings** — tunnel server section hidden/shown based on connection mode
- **App startup** — safe boot crash loop detection added
- **Default Settings Service** — default changed from WireGuard to DNS