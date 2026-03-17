# Perfect Dual Find Mode — Fix Core Issues & Add Features

## Bug Fixes (Critical)

### 1. Per-Platform Resume Tracking
- Save Joe's email/password progress and Ignition's email/password progress **separately** in the resume point
- On resume, each platform picks up exactly where it left off — no duplicate work or skipped emails
- The progress display will show accurate per-platform positions

### 2. Fix Shared Progress Counter
- Track `completedTests` accurately across both platforms so the progress bar reflects reality
- Fix `currentEmailIndex` and `currentPasswordIndex` to be tracked per-platform instead of shared

### 3. Per-Platform Pause on Hit Found
- When a login is found on Joe, **only Joe pauses** — Ignition keeps testing (and vice versa)
- The "Login Found" sheet still appears, but the other platform continues in the background
- The control bar shows which platform is paused vs. still running

---

## New Features

### 4. Add 8 Sessions (4+4) Option
- Add a new session count choice: **8 sessions (4 per platform)**
- The session picker becomes a 3-option segmented control: 4 / 6 / 8

### 5. Copy & Export Hits
- **Tap any hit** in the hits list to copy "email:password" to clipboard with a confirmation toast
- **Export All button** at the top of the hits section — copies all hits as a formatted list or shares via the system share sheet

---

## Summary of Changes
- **Model file** — Update the resume data to store per-platform positions; add the new 8-session option
- **ViewModel** — Fix the race conditions on progress tracking, implement per-platform pause logic, add copy/export functions
- **Running View** — Add copy-on-tap for hits, add export button, update status badges to show per-platform pause state
- **Setup View** — Update session picker for 3 options
