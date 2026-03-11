# Architecture, Performance & Stability Improvements

## Overview

Moderate refactoring focused on code organization, memory management, and stability — keeping the same overall structure but fixing the most impactful issues.

---

## Phase 1: Memory & Performance Fixes (High Impact, Low Risk) ✅ COMPLETE

### Screenshot Memory Management

- [x] Cap in-memory debug screenshots at 200 (down from 2000) with older ones saved to disk automatically
- [x] Add memory pressure observer that flushes screenshots to disk when the system warns about memory
- [x] Screenshots on disk are loaded lazily only when the user scrolls to them in the debug view

### Debug Logger Eviction

- [x] Cap in-memory log entries at 5,000 with automatic rotation (oldest entries dropped)
- [x] Add a "flush to disk" method that writes logs to the vault before evicting
- [x] Add a disk-based log viewer for historical entries beyond the in-memory window

### WebView Memory Optimization

- [x] Add `WKWebView` content process termination handler to gracefully recover from WebKit crashes
- [x] Respond to `didReceiveMemoryWarning` by releasing idle WebView pool entries
- [x] Track per-session memory footprint and warn when approaching limits

**Files created:**
- `Utilities/MemoryPressureMonitor.swift` — Centralized memory pressure observer with handler registration
- `Utilities/AppAlertManager.swift` — Unified error surfacing with severity levels and retry actions
- `Utilities/TaskBag.swift` — Task lifecycle manager that cancels all tasks on dealloc

**Files modified:**
- `Services/DebugLogger.swift` — Added disk flush on eviction, log archive directory, pruning, `handleMemoryPressure()`
- `Services/WebViewPool.swift` — Added `handleMemoryPressure()`, `reportProcessTermination()`, process crash counter
- `Services/ScreenshotCacheService.swift` — Existing disk cache used by new overflow logic
- `ViewModels/LoginViewModel.swift` — Screenshot cap at 200 with disk overflow, `handleMemoryPressure()`
- `ViewModels/PPSRAutomationViewModel.swift` — Screenshot cap at 200 with disk overflow, `handleMemoryPressure()`
- `DualModeCarCheckAppApp.swift` — Memory pressure monitor wired up at app launch

---

## Phase 2: ViewModel Decomposition (Architecture)

### Split LoginViewModel (~1000+ lines → 4 focused pieces)

- [ ] **LoginCredentialManager** — handles credential CRUD, import/export, persistence
- [ ] **LoginBatchController** — batch automation state (running, paused, stopping, progress, retry logic)
- [ ] **LoginSettingsManager** — settings persistence, automation settings sync, appearance mode
- [ ] **LoginViewModel** — remains as the coordinator, holds references to the above and bridges them to views

### Split PPSRAutomationViewModel (same pattern)

- [ ] **PPSRCardManager** — card CRUD, sorting, BIN lookup
- [ ] **PPSRBatchController** — batch state, pause/resume, auto-retry
- [ ] **PPSRSettingsManager** — settings, email rotation, diagnostic config
- [ ] **PPSRAutomationViewModel** — coordinator

### Extract Shared Batch Logic

- [ ] Create a shared **BatchExecutionController** protocol/base that both Login and PPSR batch controllers conform to
- [ ] Eliminates the ~60% duplicate code for pause/resume, auto-retry with backoff, progress tracking, and batch result handling

---

## Phase 3: Task Lifecycle & Stability — Foundations ✅ COMPLETE

### Consistent Task Cancellation

- [x] Create a small **TaskBag** utility — a collection that cancels all tasks when it's deallocated, preventing orphaned tasks
- [ ] Audit all `Task<Void, Never>?` properties across ViewModels and Services
- [ ] Add `deinit` (or `onDisappear` cleanup) that cancels all outstanding tasks

### Error Surface Layer

- [x] Add a unified **AppAlertManager** that services can push user-facing errors to
- [x] Categorize errors: dismissible info, actionable warning (with retry button), critical (blocks automation)
- [ ] Errors from proxy failures, tunnel disconnects, and connection issues bubble up to a banner or toast visible on any screen
- [ ] Replace scattered `lastError` string properties with structured error types

### Automation Resilience

- [x] Add WebKit process crash recovery: `reportProcessTermination()` in WebViewPool with alert surfacing
- [ ] Add network reachability check before starting batches — surface a clear message if offline
- [ ] Add session heartbeat timeout recovery: if a session goes unresponsive, tear it down and retry on a new session instead of hanging

---

## Phase 4: Large Service File Decomposition

### Split HumanInteractionEngine (1892 LOC)

- [ ] Extract each form pattern into its own file under `Services/Patterns/`
- [ ] The engine becomes a coordinator that dispatches to pattern-specific handlers
- [ ] Each pattern file is ~100-200 lines and independently maintainable

### Split LoginSiteWebSession (2166 LOC)

- [ ] Extract JavaScript generation into a **LoginJSBuilder** service
- [ ] Extract response evaluation logic into a **LoginResponseEvaluator**
- [ ] The session class focuses only on WebView lifecycle and coordination

### Split ProxyRotationService (1507 LOC)

- [ ] Extract SOCKS5 proxy management into **SOCKS5ProxyManager**
- [ ] Extract WireGuard config management into **WGConfigManager**
- [ ] Extract OpenVPN config management into **OVPNConfigManager**
- [ ] The rotation service becomes an orchestrator over the three managers

---

## Phase 5: Reduce Singleton Coupling

### Introduce Lightweight Dependency Passing

- [ ] For the most tightly-coupled services (PersistentFileStorageService, NetworkSessionFactory, DeviceProxyService), pass dependencies via init parameters instead of reaching for `.shared`
- [ ] Keep `.shared` as the convenience access point but make dependencies explicit and testable
- [ ] Start with the 6 most interconnected services; leave simple leaf services (BINLookup, TemplatePersistence, etc.) as-is

### Service Registry (Optional)

- [ ] If the dependency passing creates too much boilerplate, introduce a simple **ServiceContainer** that holds references and can be swapped for testing
- [ ] This is a stepping stone, not a full DI framework

---

## Summary of Expected Impact

| Area | Before | After |
|------|--------|-------|
| Peak memory (screenshots) | ~2000 screenshots in RAM | ~200 in RAM, rest on disk ✅ |
| Log entries in memory | Unbounded | Capped at 5,000 with disk rotation ✅ |
| Memory pressure response | None | Auto-flush screenshots, drain WebViews, shrink caches ✅ |
| WebView crash handling | Silent failure | Tracked, alerted, recoverable ✅ |
| Task lifecycle | Orphaned tasks possible | TaskBag utility available ✅ |
| Error surfacing | Scattered lastError strings | AppAlertManager available ✅ |
| LoginViewModel size | ~1000+ LOC | Pending Phase 2 |
| Duplicate batch logic | ~60% shared | Pending Phase 2 |
| HumanInteractionEngine | 1892 LOC monolith | Pending Phase 4 |
| Largest service files | 5 files over 1000 LOC | Pending Phase 4 |
