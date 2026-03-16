# Smart AI Page Settlement & Button Recovery Detection

## What Changes

Two focused improvements replacing fixed wait times with smart AI-driven detection, learned from the attached working script:

---

### **Improvement 1: Smart Page Settlement Detection**

**Problem:** After page load, the app blindly waits a fixed 2000ms hoping the page has settled. JavaScript-heavy sites may need 500ms or 8000ms — the fixed wait is either too long (wasting time) or too short (interacting with unready pages).

**Solution:** Replace the fixed `pageLoadExtraDelayMs` wait with an intelligent multi-signal page settlement detector that monitors:

- **Network idle detection** — Injects a JS observer that hooks `XMLHttpRequest` and `fetch` to track in-flight requests. Page is "network idle" when zero requests are pending for 500ms
- **DOM mutation stability** — Uses a `MutationObserver` to detect when the DOM stops changing. Page is "DOM stable" when no mutations occur for 400ms
- **Animation completion** — Checks `document.getAnimations()` to see if CSS/JS animations are still running
- **Document readyState** — Still checked but as one signal among many, not the only one
- **Login form presence** — Specifically waits until the email/password fields are present AND interactable (not just in DOM but visible, not disabled, not obscured)

The detector waits until **all signals agree** the page is settled, with a maximum timeout of 15 seconds. If settlement happens in 400ms, it proceeds in 400ms. If the page is slow, it waits as long as needed.

This replaces the fixed `pageLoadExtraDelayMs` everywhere it's used.

---

### **Improvement 2: Smart Login Button State Recovery**

**Problem:** Between submit cycles, the app checks if the button's opacity > 0.8 and isn't disabled, but doesn't detect if the button has returned to its **original visual state** (color, text, size). After a failed login, buttons often go through: original color → loading spinner/translucent → error flash → back to original. The app doesn't wait for that full cycle.

**Solution:** Replace fixed post-submit waits with a button state fingerprint system:

- **Before clicking:** Capture the button's full visual fingerprint — background color (RGB), text content, width/height, opacity, border color, box-shadow, cursor style
- **After clicking:** Poll the button every 300ms comparing current state to the saved fingerprint
- **"Recovered" = button matches its original fingerprint** (within tolerance for minor animation jitter)
- **Also detects intermediate states:** loading spinner text ("Loading...", "Please wait..."), reduced opacity, changed cursor, pointer-events: none — these are all "not yet recovered" signals
- **Timeout safety:** If the button doesn't recover within 12 seconds, proceed anyway (with a log warning)
- **AI learning:** Records how long recovery typically takes per host, so future cycles can set tighter expected windows

This replaces the fixed `submitButtonWaitDelayMs` and improves the existing `checkLoginButtonReadiness` / `waitForLoginButtonReady` functions.

---

### **Where These Changes Apply**

- The page settlement detector is used after initial page load AND after any page reload/recovery
- The button state recovery is used between every submit cycle (cycles 2+)
- Both feed timing data back to `AITimingOptimizerService` so the AI learns optimal windows per host
- Existing fixed delay settings become **maximum fallback timeouts** rather than primary waits
- All existing automation patterns benefit automatically since the changes are at the session/engine level
