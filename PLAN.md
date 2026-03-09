# Fix IP Score Test + Add Device-Wide Single IP Mode with Auto-Rotation

## What's Changing

### 1. Fix IP Score Test (Fallback URL)
- **Problem**: ipscore.io frequently fails to load
- **Fix**: Add `https://thisismyip.com` as the primary fallback URL. If ipscore.io fails to load within 10 seconds, automatically retry with thisismyip.com. Also add `https://whatismyipaddress.com` as a third fallback
- The test will cycle through URLs automatically on failure, showing which URL was used for each session
- Increase timeout to 45 seconds to give more time before marking failed

### 2. New "Device-Wide Single IP" Network Mode
**This is a major new feature** — a completely new network routing approach:

- **Current behavior**: Each web session gets its own proxy/VPN config independently (per-session IP)
- **New behavior**: A new toggle called "Unified IP Mode" where the **entire app uses ONE IP at a time**, with automatic rotation on a schedule

#### How It Works
- A new service called `DeviceProxyService` manages a single active SOCKS5 proxy connection for the entire app
- When enabled, ALL web sessions (WKWebView + URLSession) are routed through the same single proxy/VPN endpoint
- The active endpoint rotates automatically based on the selected schedule

#### Rotation Triggers (user picks one or more):
- **Every batch/auto cycle** — rotate IP at the start of each new batch
- **When IP fingerprinting is detected** — auto-rotate if fingerprint detection fires
- **Every 1 minute**
- **Every 3 minutes**
- **Every 5 minutes**
- **Every 7 minutes**
- **Every 10 minutes**
- **Every 15 minutes**

#### Rotation Source Priority:
- Uses WireGuard configs first, then falls back to OpenVPN, then SOCKS5
- Cycles through all available configs round-robin style
- Shows the currently active IP, time until next rotation, and rotation history

### 3. New Settings UI — "Device-Wide IP" Section
- Added to the existing Network Settings screen
- **Toggle**: "Unified IP Mode" (on/off) — when off, per-session mode works as before
- **Rotation interval picker**: Dropdown with all the time options listed above
- **Checkboxes**: "Rotate on batch start" and "Rotate on fingerprint detection"
- **Status display**: Shows current active endpoint, IP address, connection type (WG/OVPN/SOCKS5), time connected, and countdown to next rotation
- **Rotation log**: Shows last 20 rotations with timestamps
- **Manual rotate button**: Force an immediate IP rotation

### 4. Integration with Existing Automation
- When Unified IP Mode is enabled, the `NetworkSessionFactory` will use the single active config from `DeviceProxyService` instead of rotating per-session
- Batch start triggers call the rotation service if "rotate on batch" is enabled
- The fingerprint validation service triggers rotation if "rotate on detection" is enabled
- All existing features (split test, IP score test, login automation) automatically use the unified IP when enabled

### 5. Visual Indicators
- A small persistent banner at the top of main screens showing "🔒 Unified IP: [current endpoint] — Next rotation in X:XX"
- The banner changes color based on connection health (green = active, yellow = rotating, red = failed)
- Haptic feedback on successful rotation
