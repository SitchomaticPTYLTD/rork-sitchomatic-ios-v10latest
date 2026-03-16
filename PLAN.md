# Fix Networking Issues & Unconnected Code

## Status
- [x] Unify target host resolution through `TargetHostResolver`
- [x] Use `NetworkLayerService` health results in `NetworkSessionFactory` endpoint selection
- [x] Ensure per-session WireProxy routing is honored in `DeviceProxyService.effectiveProxyConfig`
- [x] Restrict `NetworkSessionFactory.resolveEffectiveConfig` to matching tunnel config types only
- [x] Use `TimeoutResolver`-driven timeouts in `NetworkResilienceService.sharedSession`
- [x] Rebalance `HybridNetworkingService` health scoring so strong methods can reach ~1.0
- [x] Fix `DNSPoolService.preflightTestAllActive()` tuple destructuring in `NetworkResilienceService`
- [x] Add upstream-aware pooling in `ProxyConnectionPool.acquireUpstream` and route upstream local-proxy connections through it

## Notes
- `TargetHostResolver` is now the shared source of truth for target hostnames.
- `NetworkSessionFactory` now avoids force-routing unrelated `.direct` traffic through an active local tunnel.
- Shared TLS sessions now inherit the app-wide timeout policy instead of using a stale 15-second request timeout.
- Upstream proxy pooling now differentiates direct routes from upstream routes with distinct pool keys.
