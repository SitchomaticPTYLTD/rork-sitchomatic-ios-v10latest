# Refactor 6 most critical service files one-by-one

## Refactoring Plan — 6 Files, One at a Time

Each file will be refactored when you say "yes continue". No changes to app behavior — only internal code quality improvements.

---

### File 1: HumanInteractionEngine.swift (2,121 → ~800 LOC)
- **Extract shared JS builders** — Create a `JSInteractionBuilder` helper that generates tap, fill, and submit JS snippets with parameters, eliminating copy-paste across all 12 patterns
- **Unify pattern execution** — Each pattern currently duplicates the "tap field → fill → tap next → fill → submit" flow; extract a shared pipeline with pattern-specific configuration
- **Move `LoginFormPattern` enum** to its own model file
- **Reduce inline JS** — Group reusable JS templates into a dedicated JS template struct

### File 2: DebugLoginButtonService.swift (1,219 → ~400 LOC)
- **Consolidate 40 JS snippet properties** into a data-driven method registry — one factory method that takes parameters (click type, selector strategy) instead of 40 separate computed properties
- **Extract JS generation** into a `DebugClickJSFactory` helper
- **Separate scan orchestration** from persistence and config management
- **Format JS strings** for readability (multi-line instead of single-line blobs)

### File 3: ConcurrentAutomationEngine.swift (1,406 → ~600 LOC)
- **Extract a shared `BatchOrchestrator`** that handles the common batch loop (throttling, auto-pause, stats, cooldown, preflight) used by both PPSR and Login batches
- **Move `AutomationThrottler` actor** to its own file
- **Move `BatchLiveStats` and `ConcurrentBatchResult`** to a Models file
- **Reduce the 20+ state variables** into a single `BatchState` struct that gets reset cleanly between runs

### File 4: DeviceProxyService.swift (1,158 → ~500 LOC)
- **Extract UI-facing computed properties** (labels, visibility flags) into a lightweight `ProxyDashboardState` or keep them but group clearly
- **Extract rotation logic** (timer management, index tracking, rotation execution) into a `ProxyRotationManager` helper
- **Extract per-session WireGuard/OpenVPN management** into focused helper methods
- **Reduce `didSet` side effects** — consolidate settings persistence into a single save method rather than per-property observers

### File 5: CrashProtectionService.swift (588 → ~350 LOC)
- **Extract memory monitoring** into a `MemoryMonitor` helper (growth tracking, history, death spiral detection)
- **Create a cleanup escalation table** instead of hardcoded if/else chains with magic numbers
- **Decouple from other singletons** — use a protocol/callback for cleanup actions rather than directly calling 6+ services
- **Move `CrashReport` struct** to Models

### File 6: DebugLogger.swift (818 → ~450 LOC)
- **Extract log persistence** (file I/O, export) into a `LogPersistenceService`
- **Extract session tracking** into a `LogSessionTracker`
- **Simplify the `log()` method** — it should only format and store; trimming and notification should be separate concerns
- **Move `DebugLogCategory` and `DebugLogLevel` enums** to their own model file

---

**Approach:** One file at a time. I'll complete the refactoring, build, and confirm it compiles before moving to the next. You say "yes continue" to proceed to each subsequent file.