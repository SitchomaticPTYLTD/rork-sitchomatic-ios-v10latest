# Part 1 of 10: AI-Powered Timing Optimizer for Human Interaction Engine

## What This Does

Replaces the static, hardcoded delay system in the Human Interaction Engine with an AI-driven timing optimizer that **learns per-URL** which keystroke speeds, click delays, and pause durations lead to successful form fills vs. detection/blocking.

---

### Features

- **Per-URL Timing Profiles**: The system builds and stores unique timing profiles for each host (e.g. JoeFortune vs Ignition), learning that each site has different anti-bot thresholds
- **Live Timing Adjustment**: During automation, delays are dynamically pulled from the learned profile instead of static min/max ranges — if a host blocks fast typing, future attempts automatically slow down
- **Success/Failure Tracking**: Every timing decision (keystroke delay, inter-field pause, pre-submit wait, post-DOM pause) is recorded alongside the outcome (fill success, submit success, detection triggered)
- **AI Analysis Engine**: Periodically sends aggregated timing data to the Rork Toolkit AI for deep analysis — the AI identifies patterns like "this host detects submissions faster than 400ms after password fill" and adjusts profiles
- **Decay & Freshness**: Old timing data gradually decays so the system adapts when sites update their anti-bot measures
- **Fallback Safety**: If no learned data exists for a URL, falls back to conservative human-like defaults (same as current behavior)

---

### What Gets Built/Changed

1. **New: AI Timing Optimizer Service** — Core service that stores per-host timing profiles, tracks outcomes, computes optimal delays using weighted moving averages, and calls the Rork Toolkit AI for periodic deep analysis
2. **New: Rork Toolkit API Client** — Lightweight Swift HTTP client to call the Rork Toolkit `generateText` endpoint for AI-powered timing analysis (reusable by all future AI parts)
3. **Updated: Human Interaction Engine** — Replace all `humanDelay(minMs:maxMs:)` calls with AI-optimized timing lookups; record timing outcomes after each pattern execution
4. **Updated: Login Pattern Learning** — Feed timing data into the learning system so pattern selection also considers timing success rates

---

### How It Works (User Perspective)

- **Automatic**: No settings needed — the optimizer starts with safe defaults and gets smarter with every test
- **Visible in Logs**: Debug logs show "AITiming: host X — keystroke 85ms (learned from 47 samples, 89% fill rate)" so you can see it learning
- **Persisted**: Timing profiles survive app restarts via UserDefaults
- **AI Recalibration**: Every 50 attempts per host, the AI analyzes the full timing dataset and may shift the entire profile (e.g. "slow everything down 20% for this host")

After implementation, the app will be **built and verified** before proceeding to Part 2.