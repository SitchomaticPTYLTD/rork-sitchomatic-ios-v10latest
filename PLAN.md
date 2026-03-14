# Reply 1 — Rename Dual→Double, Fix Double Mode, Add Floating PIP Status

## Part A — Rename "Dual" to "Double" everywhere

Rename all references of "Dual Mode", "DUAL", `.dual` to "Double Mode", "DOUBLE", `.double` across the entire app:

- **ProductMode enum**: `.dual` → `.double`, raw value "Double Mode"
- **LoginViewModel.SiteMode**: `.dual` → `.double`, raw value "Double"
- **TriModeSwitcher**: label "DUAL" → "DOUBLE"
- **LoginSettingsManager**: all `dualSiteMode` → `doubleSiteMode`
- **LoginViewModel**: `dualSiteMode` → `doubleSiteMode`, all dual references in logs
- **SplitTestView, DualWebStackView, ModeSelectorView**: `.dual` → `.double`
- **LoginSettingsContentView**: toggle label and binding references
- **MainMenuView**: "DUAL FIND" label stays as-is (that's a different feature — it's a search tool, not the mode)
- **ActiveAppMode.dualFind** stays unchanged (separate feature)
- Log messages updated from "DUAL" → "DOUBLE"

---

## Part B — Fix Double Mode to run equal sessions of both Joe AND Ignition

Current bug: Double Mode appears to only run Ignition sessions and crashes. The fix:

- **Split credentials 50/50** between Joe and Ignition engines — first half goes to Joe, second half to Ignition
- Both engines run **truly simultaneously** in parallel task groups with equal concurrency slots (e.g. concurrency 4 = 2 Joe + 2 Ignition)
- Fix the `useIgnition` logic that currently biases toward one engine
- Properly configure **both engines** before batch start (the secondary engine currently only gets configured for Ignition — ensure both are fully set up with correct proxy targets and URLs)
- Add crash protection: guard against nil URL arrays, task cancellation edge cases, and ensure `activeTestCount` is decremented in all code paths
- Fix the race condition where `batchCompletedCount` can exceed `batchTotalCount` when both engines finish simultaneously

---

## Part C — Floating PIP Status Pill (Navigate freely during tests)

Instead of being locked to the test screen while a batch runs, a **floating status pill** appears in the corner:

- **Design**: A small capsule overlay pinned to the **top-right** of the screen (below the safe area), showing:
  - A colored dot (green = running, orange = paused, red = stopping)
  - Live counter like **"3/50"** (completed/total)
  - Site icon (spade for Joe, flame for Ignition, branch for Double)
  - Tap to expand into a mini card showing: success count, fail count, elapsed time, ETA
  - Tap the expanded card to jump back to the session monitor screen
- **Visibility**: The pill appears on ALL screens in the app whenever a test is running — it's added as a global overlay in the app's root `ZStack`
- **Navigation**: Remove the current alert that blocks you from leaving during a test — the MainMenuButton now navigates freely; tests continue in the background
- **Haptics**: Light tap feedback when expanding/collapsing the pill
- **Animation**: Spring animation for expand/collapse, the counter updates with a subtle scale pulse

### Files involved:
- New: `FloatingTestStatusView.swift` — the PIP pill component
- Modified: `SitchomaticApp.swift` — add the floating overlay globally
- Modified: `MainMenuButton.swift` — remove the blocking alert, allow free navigation
- Modified: `LoginViewModel.swift` — expose live batch stats for the pill to observe
