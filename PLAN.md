# Fix Test & Debug — Per-Session Engine Isolation & Network Config

## Problem
The Test & Debug feature doesn't work because all concurrent sessions (6 at a time) share a single automation engine. They overwrite each other's settings (network mode, stealth, typing speed, pattern, etc.), causing every session to use whatever the last one configured. Additionally, the per-session network variation (WireGuard configs, NodeMaven, proxies) is completely ignored — the engine always uses the global app network settings instead.

## Fixes

**Per-session engine isolation**
- [x] Each session will create its own dedicated automation engine instance instead of sharing one
- [x] This prevents concurrent sessions from overwriting each other's settings

**Apply snapshot network config**
- [x] Build the correct network configuration (WireGuard, NodeMaven, SOCKS5, DNS, direct) from each session's variation snapshot
- [x] Pass it directly to the web session so each session actually uses its unique network setting

**Apply snapshot automation settings**
- [x] Each session's engine gets its own copy of automation settings from the snapshot (typing speed, stealth, pattern priority, delays, etc.)
- [x] No more race conditions between concurrent sessions

**Proper credential rotation**
- [x] Fix the credential index calculation so sessions correctly rotate through all provided credentials

**Result capture improvement**
- [x] Ensure final screenshots and error messages are properly captured even when the engine times out or hits connection failures
