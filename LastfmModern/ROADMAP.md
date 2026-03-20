# LastfmModern Migration Roadmap

## Goals
- Replace legacy Qt4/qmake mac client with a native SwiftUI + modern Apple platform stack.
- Keep core behavior parity first (scrobbling reliability and user session), then iterate UI/UX.
- Isolate Last.fm API, player listeners, and persistence behind testable service boundaries.

## Current Baseline
- Legacy app remains the behavior reference in `app/client`, `lib/listener`, and `lib/unicorn`.
- `liblastfm` may be checked out locally for protocol/behavior reference, but is not part of the tracked repo.
- `LastfmModern/` is the active product and ships as a native macOS SwiftUI app.

## Scope Priorities
1. Authentication/session management.
2. Track detection and now playing updates.
3. Scrobble queueing, retry, and submission.
4. Menu bar workflow and lightweight desktop UI.
5. Settings and diagnostics.

## Architecture Plan
- UI: SwiftUI views (`ContentView`, `NowPlayingView`, future settings/wizard views).
- App shell: `@main` app + `MenuBarExtra`.
- Domain: lightweight models (`Track`, session models).
- Services:
  - `LastfmAPI` (auth + now playing + scrobble).
  - `PlayerMonitor` (Apple Music/Spotify/system listeners via adapters).
  - `ScrobbleService` orchestration + business rules.
  - `LastfmAccountsStore` persistence for multi-account session management.
  - `ProxySettingsStore` and launch-at-login controller for app shell behavior.

## Feature Mapping (Legacy -> Modern)
- `Application` / tray menu -> SwiftUI `MenuBarExtra` + command actions.
- `ScrobbleService` -> Swift `ScrobbleService` actor/main-actor coordinator.
- `PlayerConnection` / listeners -> modular `PlayerMonitor` adapters.
- `Audioscrobbler` cache/submit -> modern queue + backoff + online/offline awareness.
- Preferences dialogs -> SwiftUI settings scene.

## Milestones
1. Foundation (Done)
- Project scaffolded and building.
- Initial service skeleton and native macOS shell created.
- Single-window architecture established for lower overhead.

2. API + Session (Done)
- Last.fm auth (`auth.getMobileSession`) implemented.
- `track.updateNowPlaying` and `track.scrobble` implemented.
- Multi-account persistence and login state implemented in UI.

3. Real Player Input (Done / Targeted expansion pending)
- Apple Music, iTunes, and Spotify listeners implemented.
- Metadata normalized to `Track`.
- Transition handling validated for start/pause/resume/stop.
- VLC support researched and technically scoped; implementation still pending.

4. Reliable Scrobbling (Done)
- Scrobble thresholds/rules parity implemented.
- Local queue persistence and retry policy implemented.
- Connection recovery and background submission implemented.
- Diagnostics and queue retry controls implemented in-app.

5. UX Parity + Modernization (In Progress)
- Main window parity for dashboard/scrobbles/profile/friends/charts implemented.
- Settings reworked into a sectioned preferences window.
- Account management, proxy controls, launch at login, and menu bar workflow implemented.
- Adaptive inspector resizing and mood-reactive dashboard visuals implemented.
- Contextual detail inspector implemented to match modernized iOS-style navigation semantics:
  - artist -> similar artists
  - track -> similar tracks
  - album -> similar albums
- Remaining work:
  - broader responsive pass across all tabs
  - VLC integration
  - optional fingerprinting reintroduction
  - tighter visual QA for light mode and ultra-wide layouts

6. Hardening + Release (In Progress)
- Logging/diagnostics screen implemented.
- Ongoing release packaging via GitHub releases.
- Remaining work:
  - stronger automated test coverage for queue/session/networking
  - signing/notarization pipeline
  - enterprise polish (proxy credential storage, deployment guidance)

## Risks and Mitigations
- Player integration differences across macOS versions:
  - Mitigate with adapter abstraction + staged rollout.
- API auth/session edge cases:
  - Mitigate with explicit state machine and error surfacing.
- Legacy behavior drift:
  - Mitigate via feature parity checklist and targeted regression tests.

## Definition of Done (Phase 1)
- User can sign in with Last.fm credentials.
- App can send now playing updates for detected tracks.
- App can queue and submit scrobbles with visible status.
- Session survives app restart.
- Preferences cover the operational essentials: accounts, proxy, startup behavior, advanced controls.
