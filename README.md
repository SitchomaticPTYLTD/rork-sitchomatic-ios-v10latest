# Sitchomatic

Native iOS app built in Swift and SwiftUI for multi-mode networked automation, login testing, PPSR card/VIN checking, BPoint biller pool testing, proxy/VPN orchestration, AI-driven automation coordination, diagnostics, flow recording, known-account optimization testing, and data export.

This README reflects a full codebase review of the current app target under `ios/Sitchomatic`.

## What the app is

Sitchomatic is a single iOS application with one main SwiftUI target that routes into multiple operational modes from a custom main menu. The app combines:

- Joe Fortune login testing and automation
- Ignition Casino login testing and automation
- PPSR card/VIN checking
- BPoint biller pool testing (1000+ biller codes)
- Test & Debug known-account optimizer (setting permutation testing)
- Device-wide network routing control
- SOCKS5 / OpenVPN / WireGuard config management
- WireProxy / local proxy bridging
- NodeMaven residential and mobile proxy integration
- NordVPN config generation and profile-based storage
- Super Test infrastructure validation
- IP score / network quality testing
- Flow recording and playback
- Split-screen dual-site testing
- Dual-site account discovery workflows
- Confidence-based result scoring
- Challenge-page classification
- Host fingerprint learning
- Adaptive retry by failure type
- URL and proxy quality scoring with decay
- AI automation coordination (27+ AI services)
- Autopilot session execution with reflex systems
- Swarm intelligence and adversarial simulation
- WebView crash recovery and lifetime budget management
- Screenshot deduplication and render-stable capture
- Session recovery and replay debugging
- Evidence bundle collection and review queues
- Debug logging, notices, diagnostics, and vault-style persistence

## Codebase at a glance

| Area | Current state |
|---|---|
| Platform | Native iOS, SwiftUI |
| Minimum target | iOS 26+ |
| App style | Single-target SwiftUI app with mode-based routing |
| Architecture | MVVM with heavy service layer |
| App entry | `SitchomaticApp.swift` |
| Primary routers | `MainMenuView`, `ActiveAppMode`, tab-based feature roots |
| Views | 94 |
| ViewModels | 19 |
| Models | 47 |
| Services | 167 (including AI layer, WireProxy subsystem, BPoint subsystem, Autopilot, and Patterns) |
| Utilities | 12 |
| Persistence | UserDefaults, documents-based vault, NSUbiquitousKeyValueStore sync, export/import JSON |
| Networking | URLSession, WebKit, proxy routing, WireGuard/OpenVPN/SOCKS5/NodeMaven selection |
| AI / ML | Vision OCR, 27+ AI coordination services, optional Foundation Models on iOS 26+ |
| Capabilities | App Groups entitlement, App Intents / Shortcuts, local notifications, Live Activities |
| Tests | Unit and UI test targets exist |

## Main app flow

The root app flow is in `SitchomaticApp.swift`.

Launch sequence:

1. Early safe-boot check (detects repeated crashes and resets to DNS-over-HTTPS mode)
2. Nord profile selection gate (`Nick` / `Poli`)
3. Main menu mode selection
4. Mode-specific root view launch
5. Background initialization:
   - memory pressure monitoring
   - vault restore
   - default settings application
   - Nord profile pool preparation
   - auto-population of configs for selected profile
   - persistence on resign/background

The app stores current mode in `@AppStorage("activeAppMode")` and uses `ActiveAppMode` as the top-level router.

## Active modes

The current `ActiveAppMode` enum contains:

- `joe`
- `ignition`
- `ppsr`
- `superTest`
- `debugLog`
- `flowRecorder`
- `nordConfig`
- `splitTest`
- `vault`
- `ipScoreTest`
- `dualFind`
- `settingsAndTesting`
- `proxyManager`
- `testDebug`

## Mode map

| Mode | Root view | Purpose |
|---|---|---|
| Joe | `LoginContentView(initialMode: .joe)` | Login automation/testing for Joe Fortune |
| Ignition | `LoginContentView(initialMode: .ignition)` | Login automation/testing for Ignition Casino |
| PPSR | `ContentView()` | PPSR card/VIN testing workflow |
| Super Test | `SuperTestContainerView` | Full infrastructure validation |
| Debug Log | `DebugLogView` | Central logging and diagnosis |
| Flow Recorder | `FlowRecorderView` | Record/replay login flows |
| Nord Config | `NordLynxConfigView` | Generate/import Nord WireGuard/OpenVPN configs |
| Split Test | `DualWebStackView` | Joe + Ignition simultaneous split interface |
| Vault | `StorageFileBrowserView` | Browse persistent document storage |
| IP Score Test | `IPScoreTestView` | 8-session IP/network quality test |
| Dual Find | `DualFindContainerView` | Multi-session, dual-site account discovery workflow |
| Settings & Testing | `SettingsAndTestingView` | Central admin, diagnostics, import/export |
| Proxy Manager | `ProxyManagerView` | Set-based proxy/config management |
| Test & Debug | `TestDebugContainerView` | Known-account optimizer with setting permutations |

## Main menu design

`MainMenuView.swift` is a custom full-screen launcher with:

- background artwork
- animated mode zones
- profile switcher for `Nick` / `Poli`
- profile-selection requirement on first launch
- Joe and Ignition zones (top row)
- Split Test and Dual Find zones (second row)
- Test & Debug zone (purple/magenta gradient with flask icon, labeled "TEST & DEBUG" / "Known Account Optimizer")
- PPSR zone
- Settings & Testing and Proxy Manager zones (bottom row)
- version number watermark

The menu is not a standard tab launcher; it is the app's mode switchboard.

## Primary user-facing surfaces

### 1. Login platform

`LoginContentView.swift` is the shell for the Joe/Ignition login product modes.

Tabs:

- Dashboard
- Credentials
- Working
- Sessions
- More

Backed by `LoginViewModel`, which manages:

- credential storage and per-credential full attempt tracking
- login attempts with minimum-attempt-before-no-account logic
- concurrency via `ConcurrentAutomationEngine`
- debug screenshots
- stealth settings
- URL rotation with quality scoring
- automation settings (patterns, typing speed, delays, viewport, human simulation)
- crop regions
- auto-retry behavior with adaptive retry by failure type
- site mode switching
- iCloud merge support
- requeue priority logic
- WebView pool with fingerprint diversity (24 webviews)

Login attempt logic:

- Credentials require a minimum number of fully completed login attempts (default 4, configurable 3-8) before being marked "No Account"
- "Temporarily disabled" detection confirms the account exists
- Credentials that haven't reached the minimum attempt threshold are requeued rather than marked dead
- Content hash duplicate threshold is set to 6 to avoid false "page stuck" bail-outs on normal error pages

The `More` menu (`LoginMoreMenuView`) links to:

- Automation Tools
- URL and endpoint settings
- Advanced settings
- Disabled-account utilities
- Temporary disabled-account list
- Blacklist
- Credential export
- Debug screenshots
- Screenshot flipbook
- Session replay debugger
- Global Settings & Testing hub

### 2. PPSR platform

`ContentView.swift` is the shell for PPSR mode.

Tabs:

- Dashboard
- Cards
- Working
- Sessions
- Settings

Backed by `PPSRAutomationViewModel`, which manages:

- PPSR cards
- PPSR checks
- BPoint biller pool testing (1000+ biller codes)
- batch execution state
- email rotation
- stealth settings
- diagnostics and connection diagnostics
- fingerprint history
- screenshot capture
- scheduler integration
- background execution
- stats tracking
- export history
- iCloud merge support
- VIN generation

### 3. Test & Debug (Known Account Optimizer)

`TestDebugContainerView.swift` hosts a three-phase workflow for finding optimal automation settings using a known working credential.

Phases:

- **Setup** (`TestDebugSetupView`) — enter up to 3 known-working email/password pairs, choose Joe or Ignition, select session count (24/48/96), choose variation mode, configure overrides
- **Running** (`TestDebugProgressView`) — live wave-based progress (waves of 6 sessions), mini session tiles, pause/stop controls
- **Results** (`TestDebugResultsView`) — dual-tab view with screenshot grid and ranked summary table, session log drill-down, compare runs, retry failed sessions, apply winning settings

Variation modes:

- **All** — vary network mode, patterns, stealth, typing speed, delays, viewport, human simulation
- **Network Focus** — different WireGuard configs, proxies, DNS, NodeMaven across sessions
- **Automation Focus** — different patterns, typing speeds, delays, stealth combos
- **Smart Matrix** — systematically vary one setting at a time to isolate what matters

Features:

- `SettingVariationGenerator` creates unique setting permutations per session
- `TestDebugVariationOverrides` allow pinning specific settings while varying others
- Full 24 WebView pool for fingerprint diversity
- End-of-test screenshot captions describing each session's differentiator
- Ranked results table sorted by outcome (success first, then by speed)
- Screenshot grid color-coded by outcome (green/red/yellow)
- Session log sheet with full timeline per session
- Run comparison view (`TestDebugCompareView`) to diff two runs side-by-side
- Saved run summaries for historical comparison
- "Apply Best Settings" to adopt winning configuration app-wide

### 4. Settings & Testing hub

`SettingsAndTestingView.swift` is the global admin surface.

Sections:

- Testing Tools
  - Super Test
  - IP Score Test
- Network & VPN
  - Device Network Settings (shows current connection mode badge)
  - Nord Config
- Debug & Diagnostics
  - Full Debug Log
  - Console (live log output)
  - Notices (with unread count badge)
- Diagnostic Reports
  - Export Diagnostic Report (clipboard)
  - Share Debug Log File
  - Share Diagnostic File
- Data Management
  - Import / Export
  - Vault
- App Settings
  - Appearance mode (System/Light/Dark)
- About
  - Version, Profile, Engine, Storage, Connection, Mode

### 5. Proxy Manager

`ProxyManagerView.swift` and `ProxyManagerViewModel.swift` provide set-based config management reachable from the bottom-right of the main menu.

Features:

- create named proxy sets
- each set holds one type only: SOCKS5 Proxy, WireGuard Config, or OpenVPN Config
- each set allows up to 10 items
- sets can be enabled/disabled
- items can be enabled/disabled
- bulk SOCKS5 import
- WireGuard file import and pasted config import
- OpenVPN file import and pasted config import
- `1 Server Per Set` becomes available only when 4+ active sets exist
- session-to-set assignment follows active set order when enabled
- proxy-set state and toggles persist locally in `UserDefaults`

### 6. Device-wide network settings

`DeviceNetworkSettingsView.swift` is the main network control surface.

Features:

- device-wide banner showing current mode and region
- IP routing picker: `Separate IP per Session` / `App-Wide United IP`
- united-IP options: rotation interval, rotate on batch start, rotate on fingerprint detection, auto-failover, rotate now, rotation log
- unified connection mode selection
- WireProxy section (WireGuard mode only)
- Proxy Dashboard (when local proxy server is running)
- WireGuard tunnel dashboard link (only when tunnel is active)
- local localhost SOCKS5 forwarder (up to 500 concurrent connections)
- NordVPN / endpoint / DNS / VPN import surfaces
- NodeMaven proxy integration (residential and mobile)
- Network Truth panel for real-time route verification
- File importing for VPN/WireGuard configs

### 7. Nord config generation

`NordLynxConfigView.swift` + `NordLynxConfigViewModel.swift` provide a full NordVPN config generator.

Features:

- protocol selection: WireGuard UDP, OpenVPN UDP, OpenVPN TCP
- country/city filtering from Nord API
- server count selection (1-50)
- config generation through Nord services
- save to documents
- export as individual files, zip archive, merged text, JSON, CSV
- import configs into app proxy/network pools
- access key management via settings sheet

### 8. Super Test

`SuperTestView.swift` + `SuperTestService.swift` implement a multi-phase infrastructure test harness.

Test phases:

- Fingerprint
- WireProxy WebView
- Joe URLs
- Ignition URLs
- PPSR connection
- DNS servers
- SOCKS5 proxies
- OpenVPN profiles
- WireGuard profiles

Outputs:

- live progress
- per-phase results with severity
- auto-fixability metadata
- pass/fail counts
- duration reporting
- optional live log panel

### 9. IP Score Test

`IPScoreTestView.swift` runs an 8-session WebKit-based network quality test.

Features:

- 8 concurrent sessions
- fallback across multiple external IP pages
- per-session network label and assigned config display
- list/tile display modes
- unified-IP banner when device-wide routing is active
- screenshot capture after page load
- network info sheet

### 10. Flow recorder and playback

`FlowRecorderView.swift` + `FlowRecorderViewModel.swift` expose a login flow recording tool.

Features:

- record WebView interactions
- save recorded flows
- playback into active WebView
- start playback from arbitrary step
- continue recording after playback
- fingerprint validation during recording workflow
- detect textboxes and map placeholders
- test individual actions against multiple methods
- save, merge, delete, and browse flows
- flow editing studio (`FlowEditingStudioView`)

### 11. Split Test

`DualWebStackView.swift` provides a Joe + Ignition simultaneous split-screen interface for side-by-side testing.

### 12. Dual Find

`DualFindContainerView.swift` + `DualFindViewModel.swift` implement a dual-site account discovery workflow.

Features:

- accepts many emails
- tests 3 passwords
- runs across 2 sites (Joe + Ignition)
- session-count presets
- persistent site session loops
- pause / resume / stop
- resume-point persistence
- hit tracking
- disabled email tracking
- local notifications
- background execution support
- minimum login attempts before declaring "no account" (configurable)

### 13. Import / export / vault

`ConsolidatedImportExportView.swift`, `AppDataExportService.swift`, and `PersistentFileStorageService.swift` form the app's data portability layer.

Export/import coverage:

- Joe URLs
- Ignition URLs
- SOCKS5 proxies
- OpenVPN configs
- WireGuard configs
- DNS providers
- blacklist
- connection modes
- network region
- unified connection mode
- automation settings
- login credentials
- PPSR cards
- login app settings
- PPSR app settings
- email rotation list
- debug button configs
- recorded flows
- sort order
- crop regions
- calibrations
- templates
- speed profile
- NordVPN keys
- temp-disabled background check flag

Import notes:

- merge-style restore
- duplicate exclusion
- v1.0 and v2.0 format support

The vault (`PersistentFileStorageService`) stores snapshots under an `AppVault` document directory with subfolders for: config, credentials, cards, network, screenshots, debug, state, flows, backups.

## Automation engine

### Login automation pipeline

The login automation pipeline is composed of several coordinated services:

- `LoginAutomationEngine` — core login attempt orchestrator
- `ConcurrentAutomationEngine` — manages concurrent session execution
- `ConcurrentSpeedOptimizer` — tunes concurrency for throughput
- `LoginSiteWebSession` — manages individual WKWebView login sessions
- `LoginWebSession` — lower-level WebView session management
- `LoginJSBuilder` — generates JavaScript for form interaction
- `JSInteractionBuilder` — general-purpose JavaScript generation for form fill, click, text extraction
- `DebugClickJSFactory` — generates debug-mode click handlers
- `HumanInteractionEngine` — simulates human-like typing, delays, mouse movement
- `HumanTypingEngine` — realistic keystroke timing patterns
- `LoginPatternLearning` — learns effective patterns per site
- `LoginCalibrationService` — calibrates field detection and timing
- `TrueDetectionService` — advanced form field and button detection
- `FlowPlaybackEngine` — replays recorded login flows
- `AutomationThrottler` — throttles automation rate to avoid detection
- `AutomationActor` — actor-based thread-safe automation state

### Autopilot subsystem

- `AutopilotActionExecutor` — executes autopilot-decided actions
- `AutopilotDecisionGraph` — decision graph for autopilot routing
- `AutopilotReflexSystem` — fast reflex responses to page signals
- `AutopilotSignalProcessor` — processes page signals for autopilot decisions
- `LiveSpeedAdaptationService` — adapts automation speed in real-time

### BPoint biller pool subsystem

The BPoint biller pool is used for PPSR card testing against 1000+ biller codes:

- `BPointAutomationEngine` — BPoint payment test automation
- `BPointBillerPoolService` — manages 1000+ biller codes with blacklisting, random selection, and pool statistics
- `BPointWebSession` — WebView interaction for BPoint forms including auto-detection of form fields and email requirements

### Intelligence and classification

- `ConfidenceResultEngine` — combines page text, URL change, DOM markers, screenshot OCR, and response timing into a confidence score before final status assignment
- `ChallengePageClassifier` — dedicated classifier for rate limit, captcha, temporary block, disabled, maintenance, and JS failure pages using OCR + DOM text + screenshot features
- `HostFingerprintLearningService` — extends pattern learning with per-site DOM/visual fingerprints so pattern choice is based on actual login page shape, not just hostname
- `OnDeviceAIService` — optional Foundation Models analysis on iOS 26 (PPSR response analysis, login page analysis, OCR-to-field mapping, flow outcome prediction, email variation generation)
- `VisionMLService` — Vision and Core Image for OCR, login field detection, button detection, disabled/success indicator discovery, saliency and foreground analysis, calibration support

### Retry and recovery

- `AdaptiveRetryService` — retry policy differs by failure type (timeout, connection failure, field detection miss, submit no-op, disabled/account state)
- `SessionRecoveryService` — captures and restores session snapshots for crash recovery
- `WebViewCrashRecoveryService` — handles `webViewWebContentProcessDidTerminate` with controlled rebuild/reload instead of blind reloads (critical for iOS 18+ long-running sessions)
- `WebViewLifetimeBudgetService` — recycles each automation WebView after N navigations to reduce iOS 18 memory buildup and process-death issues
- `BlankPageRecoveryService` — detects and recovers from blank page states
- `DeadSessionDetector` — identifies sessions that have stopped making progress
- `RequeuePriorityService` — intelligent requeue ordering based on credential state and attempt history
- `SmartButtonRecoveryService` — recovers from button detection failures
- `SmartPageSettlementService` — waits for page content to settle before interaction
- `CrashProtectionService` — crash monitoring with safe-boot mode (resets to DNS mode after repeated crashes)
- `AppStabilityCoordinator` — overall app stability coordination and memory pressure handling

### URL and proxy quality

- `URLQualityScoringService` — weighted scorer using recent latency, failure type, blank-page rate, and login success rate
- `URLCooldownService` — per-host/path cooldown when repeated timeouts/429s happen
- `LoginURLRotationService` — URL rotation with quality scoring integration
- `HostCircuitBreakerService` — short cooldown for specific hosts/paths on repeated failures
- `ProxyScoringService` — rolling quality scores per proxy
- `ProxyQualityDecayService` — rolling scores per proxy/network mode with decay over time so bad exits are demoted and recovered later
- `ProxyHealthMonitor` — continuous proxy health checking
- `ProxyConnectionPool` — managed pool of proxy connections
- `ProxyRotationService` — stores and rotates SOCKS5 / OpenVPN / WireGuard pools
- `ProxyRotationManager` — higher-level proxy rotation management
- `ProxyConfigResolver` — resolves effective proxy configuration for a session

### Screenshot and debugging

- `RenderStableScreenshotService` — waits for stable render state before taking debug screenshots (reduces blank/partial captures)
- `ScreenshotDedupService` — hashes screenshots and skips storing near-identical frames during slow debug mode
- `ScreenshotCacheService` — memory and disk caching for screenshots
- `BlankScreenshotDetector` — detects blank/empty screenshot captures
- `SessionReplayLogger` + `SessionReplayDebuggerView` — full session timeline replay for debugging
- `ReplayDebuggerService` — service layer for session replay
- `TapHeatmapOverlayView` — visual overlay showing tap interaction patterns
- `ScreenshotFlipbookView` — animated flipbook view of session screenshots

### Anti-detection

- `AntiBotDetectionService` — comprehensive anti-bot countermeasures
- `FingerprintValidationService` — validates browser fingerprint consistency
- `PPSRStealthService` — stealth measures for PPSR automation
- `WebViewPool` — pool of 24 WebViews with diverse fingerprints

### Task metrics

- `TaskMetricsCollectionService` — captures URLSessionTaskMetrics for pre-checks and network probes (DNS, connect, TLS, first-byte, transfer timing)
- `PreflightSmokeTestService` — runs a staged login probe before big batches to catch broken routes early
- `StatsTrackingService` — lifetime statistics tracking
- `BatchTelemetryService` — batch-level telemetry and metrics collection
- `SessionActivityMonitor` — monitors active session activity and summaries
- `MemoryMonitor` — monitors memory usage and pressure events
- `LiveActivityService` — Live Activity updates for Command Center widget

## Network layer

### Connection modes

The app supports four connection modes:

- DNS-over-HTTPS
- SOCKS5 Proxy
- OpenVPN
- WireGuard

And a second routing layer:

- `Separate IP per Session`
- `App-Wide United IP`

### Network services

- `DeviceProxyService` — device-wide "United IP" overlay, rotation timer, auto-failover
- `NetworkSessionFactory` — resolves effective network config for URLSession and WKWebView
- `NetworkLayerService` — network layer abstraction
- `NetworkResilienceService` — connection resilience and retry logic
- `NetworkTruthService` — real-time network route verification with history snapshots
- `NetworkRepairService` — automatic network repair and recovery
- `HybridNetworkingService` — unified networking layer combining URLSession with proxy routing
- `LocalProxyServer` — localhost SOCKS5 proxy server (up to 500 concurrent connections)
- `LocalProxyConnection` — individual proxy connection handling
- `SOCKS5ProxyManager` — SOCKS5 proxy lifecycle management
- `NodeMavenService` — NodeMaven residential and mobile proxy integration (auto-username based on proxy type: `sitchomatic...` for residential, `sitchmobile...` for mobile)
- `DNSPoolService` — DNS server pool management with multiple DoH providers

### WireProxy subsystem

The `Services/WireProxy/` directory contains a complete in-app WireGuard implementation:

- `WireProxyBridge` — main bridge between app and WireGuard tunnel
- `WireProxyTunnelConnection` — single tunnel connection management
- `WireProxyMultiTunnelConnection` — multi-tunnel support
- `WireProxySOCKS5Handler` — SOCKS5 protocol handler for WireProxy
- `WireGuardTransport` — WireGuard transport layer
- `NoiseHandshake` — Noise protocol handshake implementation
- `Blake2s` / `WireGuardCrypto` — cryptographic primitives
- `IPPacket` / `TCPPacket` — packet parsing
- `TCPSessionManager` — TCP session management
- `TunnelDNSResolver` — DNS resolution through tunnel

### VPN management

- `NordVPNService` — manages Nick/Poli profiles, access tokens, private keys, recommended servers, config auto-population
- `NordVPNKeyStore` — secure key storage for Nord credentials
- `NordLynxAPIService` — Nord API integration
- `NordLynxConfigGeneratorService` — config file generation
- `NordLynxExportService` — config export in multiple formats
- `NordLynxZipService` — zip archive creation for config export
- `NordServerIntelligence` — intelligent Nord server selection and ranking
- `VPNTunnelManager` — VPN tunnel lifecycle management
- `VPNProtocolTestService` — VPN protocol testing
- `WireGuardTunnelService` — WireGuard tunnel management
- `PerSessionTunnelManager` — per-session tunnel management for separate IP routing
- `OpenVPNProxyBridge` — OpenVPN proxy bridging
- `OpenVPNSOCKS5Handler` — SOCKS5 handler for OpenVPN connections
- `OpenVPNTunnelConnection` — OpenVPN tunnel connection management

### PPSR-specific network

- `PPSRDoHService` — DNS-over-HTTPS for PPSR
- `PPSRConnectionDiagnosticService` — PPSR connection diagnostics

## Persistence model

The app uses multiple layers of persistence:

- `UserDefaults` for settings, toggles, sort order, crop regions, profile state, generated selections
- documents storage via `PersistentFileStorageService`
- JSON export/import via `AppDataExportService`
- `NSUbiquitousKeyValueStore` for credential/card sync
- profile-prefixed storage keys for `Nick` and `Poli`
- `LoginPersistenceService` for login-specific state
- `PPSRPersistenceService` for PPSR-specific state
- `FlowPersistenceService` for recorded flows
- `TemplatePersistenceService` for automation templates
- `ExportHistoryService` for export records
- `LogPersistenceService` for persistent debug logs
- `LogSessionTracker` for log session tracking

## Profile model

Networking state is profile-aware.

- Nord profiles: `Nick` and `Poli`
- active profile affects access key, private key, and persisted proxy/VPN/WireGuard storage buckets
- profile switching triggers reload of proxy rotation, network session factory indices, and device proxy state

## AI / ML layers

### Vision-based

`VisionMLService` uses Vision and Core Image for:

- OCR/text recognition
- login field detection
- button detection
- disabled/success indicator discovery
- saliency and foreground analysis
- calibration support

### Optional on-device language model

`OnDeviceAIService` is guarded behind `canImport(FoundationModels)` and iOS 26 availability.

Uses include:

- PPSR response analysis
- login page analysis
- OCR-to-field mapping
- flow outcome prediction
- email variation generation

If Foundation Models is unavailable, the service safely returns `nil`.

### AI automation coordination

`AIAutomationCoordinator` orchestrates AI-assisted automation decisions across Vision and optional LLM layers.

### AI service layer (27 services)

The AI subsystem is a large layer of specialized services that coordinate intelligent decision-making across the app:

Session and batch intelligence:
- `AISessionAutopilotEngine` — autonomous session execution with decision-making
- `AIPredictiveBatchPreOptimizer` — pre-optimize batch configuration before execution
- `AIBatchInsightTuningTool` — tune batch parameters based on live insights
- `AISessionPreConditioningService` — pre-condition sessions for optimal start state
- `AISessionHealthMonitorService` — monitor session health and detect degradation
- `AIRunHealthAnalyzerTool` — analyze overall run health metrics

Credential and URL management:
- `AICredentialTriageService` — triage credentials by priority and likelihood
- `AICredentialPriorityScoringService` — score credential priority for batch ordering
- `AILoginURLOptimizerService` — optimize login URL selection and rotation

Confidence and verification:
- `AIConfidenceAnalyzerService` — AI-driven confidence scoring for outcomes
- `AICheckpointVerificationTool` — verify test checkpoints during execution
- `AIOutcomeRescueEngine` — rescue failing outcomes with alternative strategies

Detection and evasion:
- `AIChallengePageSolverService` — AI-driven challenge page handling
- `AIFingerprintTuningService` — optimize browser fingerprints
- `AIAntiDetectionAdaptiveService` — adaptive anti-detection countermeasures
- `AIAdversarialSimulationEngine` — adversarial testing scenarios

Network and proxy strategy:
- `AIProxyStrategyService` — AI proxy selection and rotation strategy
- `AIPredictiveRouteService` — predict optimal network routing
- `AIPredictiveConcurrencyGovernor` — predict optimal concurrency levels

Timing and performance:
- `AITimingOptimizerService` — optimize timing between automation actions
- `AIWebViewMemoryLifecycleManager` — manage WebView memory lifecycle

Learning and knowledge:
- `AIKnowledgeGraphService` — build knowledge graph of hosts, patterns, outcomes
- `AIReinforcementInteractionGraph` — reinforcement learning on interaction patterns
- `AISwarmIntelligenceService` — swarm intelligence coordination across sessions
- `AIAnomalyForecastingService` — forecast anomalies before they impact runs

Tooling:
- `AICustomToolsCoordinator` — coordinate custom AI tools and extensions

## Diagnostics and observability

- central `DebugLogger` with category/level filtering
- exported diagnostic report generation
- shareable log files
- archived log loading
- retry tracking and healing events
- `NoticesService` with unread count
- Super Test diagnostic findings with severity and auto-fixability
- persistent vault snapshots on lifecycle transitions
- memory pressure handling for logs, WebView pool, and screenshot cache
- `SessionReplayLogger` for full session timeline capture
- `ReplayDebuggerService` + `SessionReplayDebuggerView` for post-mortem session analysis
- `TapHeatmapOverlayView` for interaction pattern visualization
- `ScreenshotFlipbookView` for animated screenshot playback
- `NetworkTruthPanelView` for real-time network route verification
- `FingerprintTestView` for fingerprint validation testing

## App intents and notifications

### App Shortcuts

`AppShortcuts.swift` exposes shortcuts for:

- Check Stats
- Open PPSR Mode
- Open Joe Mode
- Open Ignition Mode
- Open NordLynx Config

### Local notifications

`PPSRNotificationService` requests authorization and the app uses notifications for connection failures and status updates.

## Capabilities and entitlements

Entitlement file contains:

- App Group: `group.app.rork.ve5l1conjgc135kle8kuj`

Other integration signals:

- `NetworkExtension` import in `VPNTunnelManager.swift`
- WebKit usage throughout automation and testing surfaces
- Vision usage for OCR/detection
- App Intents usage for Shortcuts
- UserNotifications usage for alerts
- ActivityKit usage for Live Activities (Command Center widget)
- BackgroundTasks usage for background execution

## External services and endpoints

- NordVPN credentials API, recommendations API, OVPN config download endpoints
- NodeMaven residential and mobile proxy endpoints
- PPSR CarCheck website
- Joe Fortune login URLs
- Ignition Casino login URLs
- IP verification endpoints (ipify, httpbin, ifconfig.me, etc.)
- BIN lookup providers
- DNS-over-HTTPS providers: Cloudflare, Google, Quad9, OpenDNS, Mullvad, AdGuard, NextDNS, ControlD, CleanBrowsing, DNS.SB

## Environment and configuration

Configuration is distributed across services. `RorkToolkitService` and `ServiceContainer` provide project and API configuration. `DefaultSettingsService` applies default settings on first launch.

## Full source inventory

### Root app files

- `SitchomaticApp.swift`
- `ContentView.swift`
- `LoginContentView.swift`
- `ProductMode.swift`
- `Sitchomatic.entitlements`

### Views (94 files)

- `AICustomToolsDashboardView.swift`
- `AIInsightsDashboardView.swift`
- `AIIntelligenceDashboardView.swift`
- `AIPatternDiscoveryDashboardView.swift`
- `ActiveSessionRowView.swift`
- `AdvancedSettingsView.swift`
- `AdversarialSimulationView.swift`
- `AutomationSettingsView.swift`
- `AutomationTemplateView.swift`
- `AutomationToolsMenuView.swift`
- `AutopilotDashboardView.swift`
- `BPointPoolManagementView.swift`
- `BatchIntelligenceView.swift`
- `BlacklistView.swift`
- `CheckDisabledAccountsView.swift`
- `ConsolidatedImportExportView.swift`
- `CrashReportPopupView.swift`
- `CredentialExportView.swift`
- `CredentialGroupsView.swift`
- `DebugLogView.swift`
- `DebugLoginButtonView.swift`
- `DeviceNetworkSettingsView.swift`
- `DualFindContainerView.swift`
- `DualFindRunningView.swift`
- `DualFindSetupView.swift`
- `DualWebStackView.swift`
- `EmptyStateView.swift`
- `EvidenceBundleDetailView.swift`
- `EvidenceBundleListView.swift`
- `FingerprintTestView.swift`
- `FloatingTestStatusView.swift`
- `FlowEditingStudioView.swift`
- `FlowRecorderView.swift`
- `FlowRecorderWebView.swift`
- `IPScoreTestView.swift`
- `IntroPageLink.swift`
- `LoginCalibrationView.swift`
- `LoginCredentialDetailView.swift`
- `LoginCredentialsListView.swift`
- `LoginDashboardContentView.swift`
- `LoginDashboardView.swift`
- `LoginDebugScreenshotsView.swift`
- `LoginMoreMenuView.swift`
- `LoginNetworkSettingsView.swift`
- `LoginSessionMonitorView.swift`
- `LoginSessionViews.swift`
- `LoginSettingsContentView.swift`
- `LoginWorkingListView.swift`
- `MainMenuButton.swift`
- `MainMenuView.swift`
- `ModeSelectorView.swift`
- `NetworkRepairView.swift`
- `NetworkTruthPanelView.swift`
- `NordLynxAccessKeySettingsView.swift`
- `NordLynxConfigDetailView.swift`
- `NordLynxConfigView.swift`
- `NoticesView.swift`
- `PPSRCardDetailView.swift`
- `PPSRConsoleView.swift`
- `PPSRDebugScreenshotsView.swift`
- `PPSRSettingsView.swift`
- `ProxyManagerView.swift`
- `ProxySetDetailView.swift`
- `ProxyStatusDashboardView.swift`
- `ReviewItemDetailView.swift`
- `ReviewQueueView.swift`
- `RunCommandExpandedView.swift`
- `RunCommandPillView.swift`
- `RunCommandSheetView.swift`
- `SavedCredentialsView.swift`
- `SavedFlowsView.swift`
- `ScreenshotFlipbookView.swift`
- `SessionReplayDebuggerView.swift`
- `SettingsAndTestingView.swift` (includes `SettingsConsoleView`)
- `SplitTestView.swift`
- `SplitWebViewRepresentable.swift`
- `StorageFileBrowserView.swift`
- `SuperTestContainerView.swift`
- `SuperTestView.swift`
- `TapHeatmapOverlayView.swift`
- `TempDisabledAccountsView.swift`
- `TestDebugCompareView.swift`
- `TestDebugContainerView.swift`
- `TestDebugOverridesView.swift`
- `TestDebugProgressView.swift`
- `TestDebugResultsView.swift`
- `TestDebugSessionLogSheet.swift`
- `TestDebugSetupView.swift`
- `TriModeSwitcher.swift`
- `UnifiedIPBannerView.swift`
- `VPNStatusDashboardView.swift`
- `ViewModeToggle.swift`
- `WireProxyDashboardView.swift`
- `WorkingLoginsView.swift`

### ViewModels (19 files)

- `AIInsightsViewModel.swift`
- `AIIntelligenceDashboardViewModel.swift`
- `AIPatternDiscoveryViewModel.swift`
- `AdversarialSimulationViewModel.swift`
- `BatchExecutionController.swift`
- `DualFindViewModel.swift`
- `EvidenceBundleViewModel.swift`
- `FlowRecorderViewModel.swift`
- `LoginCredentialManager.swift`
- `LoginSettingsManager.swift`
- `LoginViewModel.swift`
- `NordLynxConfigViewModel.swift`
- `PPSRAutomationViewModel.swift`
- `PPSRCardManager.swift`
- `PPSRSettingsManager.swift`
- `ProxyManagerViewModel.swift`
- `ReviewQueueViewModel.swift`
- `RunCommandViewModel.swift`
- `TestDebugViewModel.swift`

### Models (47 files)

- `AdversarialSimulationModels.swift`
- `AutomationSettings.swift`
- `AutomationTemplate.swift`
- `BatchModels.swift`
- `BatchPreset.swift`
- `CommandCenterActivityAttributes.swift`
- `CrashReport.swift`
- `CredentialGroup.swift`
- `DebugLogModels.swift`
- `DebugLoginButtonConfig.swift`
- `DeviceProxyModels.swift`
- `DualFindState.swift`
- `EvidenceBundle.swift`
- `ExportRecord.swift`
- `FailureNotice.swift`
- `KnowledgeGraphModels.swift`
- `LoginAttempt.swift`
- `LoginAttemptStatus.swift`
- `LoginCredential.swift`
- `LoginFormPattern.swift`
- `LoginTestResult.swift`
- `NordLynxAccessKey.swift`
- `NordLynxCountryResponse.swift`
- `NordLynxExportFormat.swift`
- `NordLynxGeneratedConfig.swift`
- `NordLynxServerResponse.swift`
- `NordLynxVPNProtocol.swift`
- `OpenVPNConfig.swift`
- `PPSRBINData.swift`
- `PPSRCard.swift`
- `PPSRCheck.swift`
- `PPSRCheckStatus.swift`
- `PPSRDebugScreenshot.swift`
- `PPSRLogEntry.swift`
- `PPSRTestResult.swift`
- `ProxyConfig.swift`
- `ProxySet.swift`
- `RecordedAction.swift`
- `RecordedFlow.swift`
- `ReviewItem.swift`
- `SessionRecoverySnapshot.swift`
- `SharedTypes.swift`
- `SwarmIntelligenceModels.swift`
- `TestDebugSession.swift`
- `TestGateway.swift`
- `TestSchedule.swift`
- `WireGuardConfig.swift`

### Services (167 files)

Core automation:
- `LoginAutomationEngine.swift`
- `ConcurrentAutomationEngine.swift`
- `ConcurrentSpeedOptimizer.swift`
- `LoginSiteWebSession.swift`
- `LoginWebSession.swift`
- `LoginJSBuilder.swift`
- `JSInteractionBuilder.swift`
- `DebugClickJSFactory.swift`
- `HumanInteractionEngine.swift`
- `LoginPatternLearning.swift`
- `LoginCalibrationService.swift`
- `FlowPlaybackEngine.swift`
- `AutomationActor.swift`
- `AutomationThrottler.swift`

Autopilot:
- `AutopilotActionExecutor.swift`
- `AutopilotDecisionGraph.swift`
- `AutopilotReflexSystem.swift`
- `AutopilotSignalProcessor.swift`
- `LiveSpeedAdaptationService.swift`

BPoint biller pool:
- `BPointAutomationEngine.swift`
- `BPointBillerPoolService.swift`
- `BPointWebSession.swift`

AI layer (27 services):
- `AIAutomationCoordinator.swift`
- `AISessionAutopilotEngine.swift`
- `AIPredictiveBatchPreOptimizer.swift`
- `AIBatchInsightTuningTool.swift`
- `AISessionPreConditioningService.swift`
- `AISessionHealthMonitorService.swift`
- `AIRunHealthAnalyzerTool.swift`
- `AICredentialTriageService.swift`
- `AICredentialPriorityScoringService.swift`
- `AILoginURLOptimizerService.swift`
- `AIConfidenceAnalyzerService.swift`
- `AICheckpointVerificationTool.swift`
- `AIOutcomeRescueEngine.swift`
- `AIChallengePageSolverService.swift`
- `AIFingerprintTuningService.swift`
- `AIAntiDetectionAdaptiveService.swift`
- `AIAdversarialSimulationEngine.swift`
- `AIProxyStrategyService.swift`
- `AIPredictiveRouteService.swift`
- `AIPredictiveConcurrencyGovernor.swift`
- `AITimingOptimizerService.swift`
- `AIWebViewMemoryLifecycleManager.swift`
- `AIKnowledgeGraphService.swift`
- `AIReinforcementInteractionGraph.swift`
- `AISwarmIntelligenceService.swift`
- `AIAnomalyForecastingService.swift`
- `AICustomToolsCoordinator.swift`

Intelligence:
- `ConfidenceResultEngine.swift`
- `ChallengePageClassifier.swift`
- `HostFingerprintLearningService.swift`
- `TrueDetectionService.swift`
- `OnDeviceAIService.swift`
- `VisionMLService.swift`

Retry and recovery:
- `AdaptiveRetryService.swift`
- `SessionRecoveryService.swift`
- `WebViewCrashRecoveryService.swift`
- `WebViewLifetimeBudgetService.swift`
- `BlankPageRecoveryService.swift`
- `DeadSessionDetector.swift`
- `RequeuePriorityService.swift`
- `SmartButtonRecoveryService.swift`
- `SmartPageSettlementService.swift`
- `CrashProtectionService.swift`
- `AppStabilityCoordinator.swift`

URL and proxy quality:
- `URLQualityScoringService.swift`
- `URLCooldownService.swift`
- `LoginURLRotationService.swift`
- `HostCircuitBreakerService.swift`
- `ProxyScoringService.swift`
- `ProxyQualityDecayService.swift`
- `ProxyHealthMonitor.swift`
- `ProxyConnectionPool.swift`
- `ProxyRotationService.swift`
- `ProxyRotationManager.swift`
- `ProxyConfigResolver.swift`

Screenshots and debugging:
- `RenderStableScreenshotService.swift`
- `ScreenshotDedupService.swift`
- `ScreenshotCacheService.swift`
- `SessionReplayLogger.swift`
- `ReplayDebuggerService.swift`
- `DebugLogger.swift`
- `DebugLoginButtonService.swift`

Anti-detection:
- `AntiBotDetectionService.swift`
- `FingerprintValidationService.swift`
- `PPSRStealthService.swift`
- `WebViewPool.swift`

Network:
- `DeviceProxyService.swift`
- `NetworkSessionFactory.swift`
- `NetworkLayerService.swift`
- `NetworkResilienceService.swift`
- `NetworkTruthService.swift`
- `NetworkRepairService.swift`
- `HybridNetworkingService.swift`
- `LocalProxyServer.swift`
- `LocalProxyConnection.swift`
- `SOCKS5ProxyManager.swift`
- `NodeMavenService.swift`
- `DNSPoolService.swift`

VPN:
- `NordVPNService.swift`
- `NordVPNKeyStore.swift`
- `NordLynxAPIService.swift`
- `NordLynxConfigGeneratorService.swift`
- `NordLynxExportService.swift`
- `NordLynxZipService.swift`
- `NordServerIntelligence.swift`
- `VPNTunnelManager.swift`
- `VPNProtocolTestService.swift`
- `WireGuardTunnelService.swift`
- `PerSessionTunnelManager.swift`

OpenVPN:
- `OpenVPNProxyBridge.swift`
- `OpenVPNSOCKS5Handler.swift`
- `OpenVPNTunnelConnection.swift`

PPSR:
- `PPSRAutomationEngine.swift`
- `PPSRConnectionDiagnosticService.swift`
- `PPSRDoHService.swift`
- `PPSREmailRotationService.swift`
- `PPSRNotificationService.swift`
- `PPSRPersistenceService.swift`
- `PPSRStealthService.swift`
- `PPSRVINGenerator.swift`

Metrics and monitoring:
- `TaskMetricsCollectionService.swift`
- `PreflightSmokeTestService.swift`
- `StatsTrackingService.swift`
- `SuperTestService.swift`
- `SettingVariationGenerator.swift`
- `BatchTelemetryService.swift`
- `SessionActivityMonitor.swift`
- `MemoryMonitor.swift`
- `LiveActivityService.swift`

Persistence:
- `PersistentFileStorageService.swift`
- `AppDataExportService.swift`
- `LoginPersistenceService.swift`
- `FlowPersistenceService.swift`
- `TemplatePersistenceService.swift`
- `ExportHistoryService.swift`
- `LogPersistenceService.swift`
- `LogSessionTracker.swift`

Other:
- `AppShortcuts.swift`
- `BackgroundTaskService.swift`
- `BatchPresetService.swift`
- `BINLookupService.swift`
- `BlacklistService.swift`
- `CredentialGroupService.swift`
- `DefaultSettingsService.swift`
- `DisabledCheckService.swift`
- `EvidenceBundleService.swift`
- `NoticesService.swift`
- `ReviewQueueService.swift`
- `RorkToolkitService.swift`
- `ServiceContainer.swift`
- `TempDisabledCheckService.swift`
- `TestSchedulerService.swift`
- `URLRotationService.swift`
- `UserInterventionLearningService.swift`
- `XLSXParserService.swift`

Patterns:
- `Patterns/HumanTypingEngine.swift`

WireProxy subsystem:
- `WireProxy/WireProxyBridge.swift`
- `WireProxy/WireProxyTunnelConnection.swift`
- `WireProxy/WireProxyMultiTunnelConnection.swift`
- `WireProxy/WireProxySOCKS5Handler.swift`
- `WireProxy/Transport/WireGuardTransport.swift`
- `WireProxy/Handshake/NoiseHandshake.swift`
- `WireProxy/Crypto/Blake2s.swift`
- `WireProxy/Crypto/WireGuardCrypto.swift`
- `WireProxy/TCPStack/IPPacket.swift`
- `WireProxy/TCPStack/TCPPacket.swift`
- `WireProxy/TCPStack/TCPSessionManager.swift`
- `WireProxy/TCPStack/TunnelDNSResolver.swift`

### Utilities (12 files)

- `AppAlertManager.swift`
- `BatchAlertModifier.swift`
- `BlankScreenshotDetector.swift`
- `ContinuationGuard.swift`
- `DateFormatters.swift`
- `GreenBannerDetector.swift`
- `MainMenuOverlay.swift`
- `MemoryPressureMonitor.swift`
- `ShareSheetView.swift`
- `TargetHostResolver.swift`
- `TaskBag.swift`
- `TimeoutResolver.swift`

## Current state summary

This codebase is a large, single-target operational SwiftUI app centered around five pillars:

1. **Automation workflows** — login testing across Joe Fortune and Ignition Casino with confidence-based scoring, adaptive retry, challenge classification, host fingerprint learning, BPoint biller pool testing, and known-account optimization testing
2. **Network/proxy/VPN control** — device-wide routing with SOCKS5, OpenVPN, WireGuard, NodeMaven, DNS-over-HTTPS, quality scoring with decay, circuit breakers, and a full in-app WireProxy implementation
3. **AI intelligence layer** — 27+ AI services for autopilot, predictive optimization, credential triage, fingerprint tuning, swarm intelligence, adversarial simulation, knowledge graphs, and reinforcement learning, plus Vision OCR and optional on-device LLM
4. **Diagnostics and state portability** — comprehensive logging, session replay debugging, screenshot flipbooks, tap heatmaps, network truth verification, vault snapshots, and full import/export
5. **Autopilot and reflex systems** — autonomous session execution with decision graphs, signal processing, reflex responses, and live speed adaptation

It is not a small sample project. It is a tool-heavy app with 14 operational modes, profile-aware network state, a deep service layer of 167 services, and strong built-in export/debug/replay support.
