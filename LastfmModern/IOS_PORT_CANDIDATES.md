# iOS Feature Port Candidates (from `lastfm/lastfm-iphone`)

Source explored: [lastfm/lastfm-iphone](https://github.com/lastfm/lastfm-iphone)

## Port First (high value)

1. Scrobble reliability state machine and queue backoff
- iOS reference:
  - `Classes/Scrobbler.m`
  - queue persistence (`queue.plist`), duplicate guard (`lastScrobble`), exponential queue flush backoff (2s -> 7200s), offline checks.
- macOS status:
  - We already have queue persistence + duplicate filtering + thresholds.
- next upgrade:
  - add explicit exponential retry scheduler for failed queue submit attempts (instead of user-trigger/manual submit only).

2. Early now-playing submit with pause-aware removal
- iOS reference:
  - `Classes/Scrobbler.m` sends now playing after ~10s and removes it on pause.
- macOS status:
  - we send now playing on track start.
- next upgrade:
  - delay now-playing send by configurable threshold (e.g. 10s), and optionally clear now playing when paused/stopped.

3. Diagnostics surface with live runtime stats
- iOS reference:
  - `Classes/DebugViewController.m` shows buffer stats and service error information.
- macOS status:
  - diagnostics section exists.
- next upgrade:
  - add retry timer state, queue flush attempts, last network status transition, and per-player event counters.

4. Session bootstrap hardening
- iOS reference:
  - `Classes/MobileLastFMApplicationDelegate.m` refreshes session/account capability data at startup (`getSessionInfo`) and updates local flags.
- next upgrade:
  - add a startup session validation/check endpoint and capabilities cache (subscriber/trial-like account flags if available).

## Port Next (medium value)

5. API response cache policy by endpoint
- iOS reference:
  - `Classes/LastFMService.m` applies per-method max cache age and fallback-to-cache behavior.
- next upgrade:
  - add structured HTTP cache policy in `LastfmAPIClient` per endpoint class:
  - metadata/search endpoints: cache with TTL
  - auth/scrobble endpoints: no cache

6. Cache housekeeping
- iOS reference:
  - `MobileLastFMApplicationDelegate.m` cleans stale cache files and preserves critical state.
- next upgrade:
  - periodic cleanup for stale metadata cache and bounded queue/log files.

7. Search result normalization and URI routing
- iOS reference:
  - `Classes/Search.m` merges artist/album/track/tag results and maps to internal URI routes.
- next upgrade:
  - define a unified `SearchResult` model and route handling for macOS views/actions.

## Nice to have

8. Share workflows
- iOS reference:
  - `ShareKit` integration for track/artist/album sharing.
- macOS recommendation:
  - use native `NSSharingServicePicker` instead of porting ShareKit.

9. Artwork fallback chain
- iOS reference:
  - `LastFMRadio.m` falls back album -> track -> artist image and updates now playing metadata.
- macOS recommendation:
  - keep current metadata chain but add richer fallback pipeline and image cache key strategy.

## Do Not Port (legacy / risky)

- `allowsAnyHTTPSCertificateForHost` hack in `LastFMService.m`.
- Old third-party stacks:
  - `Three20`, `TouchXML`, legacy analytics SDKs (`Flurry`, `TestFlight`) from this repo.
- iOS-specific UI paradigms and deprecated APIs.

## Proposed immediate implementation sequence

1. Queue retry scheduler with exponential backoff + jitter.
2. Deferred now-playing (10s) and pause/stop now-playing lifecycle.
3. Startup session validation and capabilities cache.
4. Endpoint-level cache policy for read-only metadata/search methods.
