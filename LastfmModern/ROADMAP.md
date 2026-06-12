# LastfmModern Migration Roadmap

## Goals
- Replace legacy Qt4/qmake mac client with a native SwiftUI + modern Apple platform stack.
- Keep core behavior parity first (scrobbling reliability and user session), then iterate UI/UX.
- Isolate Last.fm API, player listeners, and persistence behind testable service boundaries.

## Current Baseline
- Legacy app remains the behavior reference in `app/client`, `lib/listener`, and `lib/unicorn`.
- `liblastfm` may be checked out locally for protocol/behavior reference, but is not part of the tracked repo.
- `LastfmModern/` is the active product and ships as a native macOS SwiftUI app.
- Engineering practices are now documented in `../docs/ENGINEERING_PRACTICES.md`.
- The active Swift codebase has been regularized into focused files; no current Swift source file is above the documented 600-line review threshold.

## Scope Priorities
1. Authentication/session management.
2. Track detection and now playing updates.
3. Scrobble queueing, retry, and submission.
4. Menu bar workflow and lightweight desktop UI.
5. Settings and diagnostics.

## Architecture Plan
- UI: SwiftUI feature views split by responsibility.
  - `ContentView` owns shell composition, navigation, modal state, and feature wiring.
  - Feature surfaces live in focused files such as `DashboardView`, `ScrobblesView`, `ReportsView`, `ChartsView`, `FriendsView`, and `NeighboursView`.
  - Shared presentation helpers live in focused UI support files.
- App shell: `@main` app + `MenuBarExtra`.
- Domain: lightweight models such as `Track` and `SocialGraph`.
- Services:
  - `LastfmAPI` protocol, config, errors, and typed value models.
  - `LastfmAPIClient` split by auth, scrobbling, metadata, profile, social, transport, and web fallback behavior.
  - `PlayerMonitor` (Apple Music/Spotify/system listeners via adapters).
  - `ScrobbleService` orchestration split by account/session, inspection, playback queue, refresh, and social graph behavior.
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
- UI structure regularized so each major tab and shared helper has a focused source file.
- Remaining work:
  - broader responsive pass across all tabs
  - VLC integration
  - optional fingerprinting reintroduction
  - tighter visual QA for light mode and ultra-wide layouts

6. Engineering Hardening (In Progress)
- Engineering practices document added and applied to the active codebase.
- Oversized `ContentView`, `LastfmAPI`, and `ScrobbleService` files split into focused source files.
- Current automated suite passes after the structural refactor.
- Remaining work:
  - migrate stable Last.fm response parsing from dynamic `[String: Any]` dictionaries toward `Decodable` request/response models
  - add endpoint-level tests for metadata, profile, friends, neighbours, and fallback parsing
  - add focused tests around account switching, proxy transport selection, and social graph computation
  - reduce broad shared mutable state in `ScrobbleService` where narrower collaborators become worthwhile

7. Release + Distribution (In Progress)
- Logging/diagnostics screen implemented.
- Ongoing release packaging via GitHub releases.
- Remaining work:
  - signing/notarization pipeline
  - enterprise polish (proxy credential storage, deployment guidance)
  - release checklist that ties version bumps, tests, packaging, and GitHub release assets together

## Risks and Mitigations
- Player integration differences across macOS versions:
  - Mitigate with adapter abstraction + staged rollout.
- API auth/session edge cases:
  - Mitigate with explicit state machine and error surfacing.
- Legacy behavior drift:
  - Mitigate via feature parity checklist and targeted regression tests.
- Last.fm response and web fallback variability:
  - Mitigate with typed decoding where stable, deterministic fallbacks where loose, and fixture-based tests.
- Service state complexity:
  - Mitigate by keeping future changes in the existing extension boundaries and extracting narrower collaborators only with behavior-preserving tests.

## Definition of Done (Phase 1)
- User can sign in with Last.fm credentials.
- App can send now playing updates for detected tracks.
- App can queue and submit scrobbles with visible status.
- Session survives app restart.
- Preferences cover the operational essentials: accounts, proxy, startup behavior, advanced controls.

## Definition of Done (Quality Baseline)
- New Swift source files stay under the documented size threshold unless there is a clear architectural reason.
- Existing feature/service boundaries remain intact when adding behavior.
- Service, parsing, queue, session, and migration-sensitive changes include targeted tests.
- The active macOS test command succeeds before release-facing changes are merged.
