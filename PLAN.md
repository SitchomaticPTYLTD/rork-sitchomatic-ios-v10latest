# Improvement Plan

## Stage 1 — Bug Fixes & Broken Features (COMPLETE)

Conservative changes only — fix what's broken without restructuring.

---

### **Bug Fixes**

- [x] **Fix duplicate "Select Testing" button** — Updated LoginSettingsContentView to open a credential selection sheet instead of calling testAllUntested(). LoginDashboardContentView already had the correct implementation.

- [x] **Confirmation dialogs on destructive actions** — Already implemented. All Purge buttons (Dead Cards, No Account, Perm Disabled, Unsure) already had confirmation alerts with item counts.

- [x] **Pull-to-refresh on key screens** — Already implemented. WorkingLoginsView, SavedCredentialsView, LoginDashboardView, LoginDashboardContentView, and LoginWorkingListView all had .refreshable.

---

### **Reliability Fixes**

- [x] **Network health check coverage** — SuperTestService already tests all enabled configs across all targets (joe, ignition, ppsr) for SOCKS5, OpenVPN, and WireGuard.

- [x] **NordVPN API retry logic** — Added retry with exponential backoff (up to 3 attempts) on both fetchPrivateKey() and fetchRecommendedServers() for transient errors (timeout, connection lost, 429/502/503/504).

- [x] **IPScoreWebViewDelegate concurrency** — Already had nonisolated markers on all WKNavigationDelegate methods.

---

### **Data Safety**

- [x] **Full state saves off main thread** — Already using Task.detached(priority: .utility) for encoding and file writes.

- [x] **Screenshot cache size management** — Added configurable max cache size (200MB default), size-based eviction (trims to 75% when exceeded), and exposed setMaxCacheCounts() API.

---

## Stage 2 — UX Polish & Performance (COMPLETE)

Improve the user experience and app responsiveness.

### **UX Improvements**

- [x] **Add empty state illustrations** — Enhanced EmptyStateView with optional tips section. Added contextual tips to Dashboard, Working Cards, Saved Cards, and Credentials empty states with import format hints and action guidance.

- [x] **Add batch progress indicator** — Added batchTotalCount/batchCompletedCount/batchProgress to both PPSRAutomationViewModel and LoginViewModel. Dashboard testing banners now show a ProgressView bar with completed/total count and percentage.

- [x] **Improve error messages** — Added connectionGuidance computed property to LoginDashboardView that analyzes diagnostic report failures (DNS, blocking, timeout, CAPTCHA) and shows actionable guidance below the connection status.

- [x] **Add sort persistence** — PPSRAutomationViewModel cardSortOption/cardSortAscending now save to and restore from UserDefaults. LoginCredentialsListView sort options persist via onChange handlers.

### **Performance**

- [x] **Lazy load BIN data** — Added in-flight request deduplication to BINLookupService using a Task dictionary. Concurrent lookups for the same BIN prefix now share a single network request.

- [x] **Optimize credential list rendering** — LoginCredentialsListView now caps visible list to 500 items with a "use search to narrow results" hint when exceeded.

- [x] **Add network request deduplication** — Both PPSRAutomationViewModel and LoginViewModel testConnection() now cancel any in-flight connection test before starting a new one via connectionTestTask tracking.
