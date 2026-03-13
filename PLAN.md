# Part 3: Auto-Apply Winner, Connection Pre-Check & Heatmap

**Part 3 of the Test & Debug improvements (items 8–10):**

## Features

- **Apply Winner Settings** — On the results screen, the gold winner card gets an "Apply These Settings" button that copies the winning session's configuration (network mode, pattern, typing speed, stealth, etc.) directly into the app's active automation settings with one tap
- **Connection Pre-Check** — Before each session attempts a login, a quick connectivity probe runs against the target site using that session's network config. Sessions with dead/unreachable connections are immediately marked as "Connection Failure" instead of wasting 90 seconds on a timeout
- **Heatmap Visualization** — A new third tab ("Heatmap") on the results screen shows a color-coded matrix of which setting dimensions (network mode, pattern, typing speed, stealth, human sim, isolation) correlated with success vs failure, making it easy to spot winning combos at a glance

## Design

- **Apply Winner button** — Purple gradient button below the winner card text, with a "wand.and.stars" icon; triggers a haptic confirmation and shows a brief "Settings Applied ✓" toast
- **Pre-check indicator** — Each session tile briefly shows a "signal checking" animation before transitioning to "running"; failed pre-checks show immediately as connection failures with a "wifi.slash" icon
- **Heatmap tab** — Grid layout with setting dimensions as rows and values as columns; each cell is color-coded from deep red (0% success) through yellow (50%) to bright green (100%); cell shows the fraction (e.g. "3/4") for quick reading

## Screens

- **Results Screen** — Updated with 3 tabs: Grid, Ranked, Heatmap. Winner card now includes the Apply button
- **Heatmap Tab** — Scrollable grid showing success rates broken down by Network Mode, Pattern, Typing Speed, Stealth ON/OFF, Human Sim ON/OFF, and Session Isolation mode
