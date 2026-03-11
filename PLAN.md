# Fix WireProxy DNS resolution and connection capacity

## Problem
WireProxy tunnel connects successfully (handshake works), but **every DNS lookup fails** because of a bug in how DNS responses are parsed. This means no website can ever load through the tunnel.

A secondary issue is that the connection limit (50) is too low — failed DNS causes rapid retries that exhaust all connection slots.

## Fixes

**1. Fix DNS response parser (root cause)**
- The DNS answer record parser skips the wrong number of bytes — it misses the 4-byte TTL field, causing it to read garbage data instead of the actual record length
- Fix: add the missing 4-byte skip so the parser correctly reads the record type and data length
- This will make DNS resolution work, which means websites will actually load through the tunnel

**2. Increase connection capacity**
- Raise the maximum simultaneous connections from 50 to 200
- This prevents the cascading "rejected connection" failures when multiple browser sessions are running tests at the same time

**3. Add DNS retry with fallback**
- If the primary DNS server (from the WireGuard config, e.g. 103.86.96.100) fails to resolve, automatically retry with a public DNS server (1.1.1.1) as fallback
- This adds resilience if NordVPN's DNS server is slow or unresponsive
