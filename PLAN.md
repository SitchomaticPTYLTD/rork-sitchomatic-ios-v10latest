# Fix Login Attempt Logic: Require 3+ Attempts Before "No Account" & Fix Content Hash Bail-Out

## Problem
The app currently declares "No Account" too quickly. The correct logic is:
- **Temporarily Disabled = the account EXISTS** (wrong password triggered a lock)
- **3+ fully completed login attempts with NO temp disabled = No Account**
- For safety, 4–5 full attempts before concluding no account
- Seeing the same "incorrect password" page across cycles is normal — the app shouldn't bail out calling it "stuck"

## Changes

### 1. Remove Content Hash Bail-Out (Too Aggressive)
- [x] Currently, 2 consecutive identical page content hashes causes the engine to declare "page stuck" and abort
- [x] This is wrong because seeing the same "incorrect password" error page across multiple submit cycles is **expected behavior**
- [x] **Change:** Increase the duplicate content hash threshold from 2 to 6, so it only triggers for truly stuck pages (not normal error repetition)

### 2. Use the Setting Instead of Hardcoded Cycles
- [x] The engine hardcodes `maxSubmitCycles = 4` but there's already a setting `automationSettings.maxSubmitCycles` (default 5)
- [x] **Change:** Use the setting value, and increase the default from 5 to 5 (keeping it, but now actually using it)

### 3. Add "Minimum Attempts Before No Account" Setting
- [x] New setting: **Min Attempts Before No Acc** (default: 4, range 3–8)
- [x] This tracks how many **full login runs** (not just cycles within one run) a credential needs before it can be marked "No Account"
- [x] Appears in the Automation Settings screen under the Retry / Requeue section

### 4. Track Full Attempt Count Per Credential
- [x] Add a counter on each credential that tracks how many **fully completed login attempts** (where the form was filled and submitted) have occurred
- [x] This persists across batch runs so the app remembers previous attempts

### 5. Requeue Instead of Marking "No Account" Too Early
- [x] When the engine returns "noAcc" but the credential hasn't reached the minimum attempt threshold yet:
  - [x] **Don't mark as No Account**
  - [x] **Don't blacklist**
  - [x] Instead, reset to "Untested" and requeue to bottom for another attempt
  - [x] Log: "Incorrect password but only X/4 attempts — requeuing for confirmation"
- [x] Only after reaching the minimum (default 4) fully completed attempts with no "temporarily disabled" seen → mark as No Account and blacklist

### 6. Temp Disabled = Account Confirmed
- [x] When "temporarily disabled" is detected, the credential is confirmed to have an active account
- [x] Log clearly: "ACCOUNT CONFIRMED — temp disabled means account exists"
- [x] If the credential has assigned alternative passwords, it should be queued for retry with the next password

### 7. Settings UI Update
- [x] Add the new "Min Attempts Before No Acc" stepper (3–8) in the Automation Settings under Retry / Requeue
- [x] Add a label explaining: "Minimum full login attempts before declaring No Account (temp disabled = account exists)"
