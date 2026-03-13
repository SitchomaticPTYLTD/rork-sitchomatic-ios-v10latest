# Increase Connection Limit, Rework IP Mode Toggle & Clean Up WireProxy Visibility

## Changes

### 1. Max Concurrent Connections → 500
- [x] Increase the local proxy server's connection cap from 200 to 500 so high-burst test runs (like 8 concurrent IP score sessions) don't get rejected at capacity

### 2. Rework "Unified IP Mode" into IP Routing Toggle
- [x] Replace the current "Unified IP Mode" on/off toggle with a clear two-option picker:
  - **"Separate IP per Session"** — each web session gets its own IP from the config pool (current behavior when unified is OFF)
  - **"App-Wide United IP"** — the entire app shares one IP that auto-rotates on a schedule (current behavior when unified is ON)
- [x] Apply this across the Network Settings screen, the banner at the top of Joe/Ignition/PPSR views, and other surfaced UI references. The rotation interval, rotate-on-batch, rotate-on-fingerprint, and rotate-now controls remain under the "App-Wide United IP" option.

### 3. Separate WireProxy from IP Mode
- [x] Move the WireProxy server toggle and dashboard out of the IP routing section so it reads as a separate feature
- [x] Keep WireProxy as its own independent section in Network Settings, labeled as the on-device SOCKS5 tunnel forwarder
- [x] Keep the WireGuard Tunnel dashboard link inside that WireProxy section

### 4. Only Show WireProxy When Compatible
- [x] Only show the WireProxy server section when the connection mode is set to **WireGuard**
- [x] Hide WireProxy entirely for DNS, SOCKS5 Proxy, OpenVPN, and other incompatible modes
- [x] Only show the WireProxy dashboard navigation link when `wireProxyBridge.isActive`

### 5. Full Networking Review Pass
- [x] Audit `NetworkSessionFactory` to keep WireProxy tunnel routing prioritized only when active and compatible
- [x] Verify `DeviceProxyService` properly handles the renamed IP routing states and connection-mode changes
- [x] Ensure `AppDataExportService` exports/imports the new IP routing naming and settings correctly
- [x] Update banner view (`UnifiedIPBannerView`) to reflect the new naming — show "United IP" when app-wide mode is active, hide when per-session mode is active
- [x] Confirm Super Test's WireProxy WebView phase checks tunnel availability before running
- [x] Clean up stale surfaced references to the old "Unified IP Mode" naming across the main affected views

## Additional Requests

### 6. Rename app branding and files to Sitchomatic
- [x] Rename the app target, project references, app folder, entitlements file, and test targets from DualModeCarCheckApp to Sitchomatic

### 7. Slow Debug Mode for Automation
- [x] Add a slow debug mode in Automation Config that captures a screenshot every 2 seconds during login automation
- [x] Force slow debug mode to run only 1 login session at a time across batch execution and dashboard controls
