# LastfmModern Migration Roadmap

## Goals
- Replace legacy Qt4/qmake mac client with a native SwiftUI + modern Apple platform stack.
- Keep core behavior parity first (scrobbling reliability and user session), then iterate UI/UX.
- Isolate Last.fm API, player listeners, and persistence behind testable service boundaries.

## Current Baseline
- Legacy app remains the behavior reference in `app/client`, `lib/listener`, and `lib/unicorn`.
- `liblastfm` is now integrated as a submodule for protocol/behavior reference.
- New SwiftUI app scaffold exists in `LastfmModern/`.

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
  - `SessionStore` persistence (Keychain for session key, user defaults for metadata).

## Feature Mapping (Legacy -> Modern)
- `Application` / tray menu -> SwiftUI `MenuBarExtra` + command actions.
- `ScrobbleService` -> Swift `ScrobbleService` actor/main-actor coordinator.
- `PlayerConnection` / listeners -> modular `PlayerMonitor` adapters.
- `Audioscrobbler` cache/submit -> modern queue + backoff + online/offline awareness.
- Preferences dialogs -> SwiftUI settings scene.

## Milestones
1. Foundation (Done/In Progress)
- Project scaffolded and building.
- `liblastfm` integrated as submodule.
- Initial service skeleton and basic UI created.

2. API + Session (In Progress)
- Implement Last.fm auth (`auth.getMobileSession`).
- Implement `track.updateNowPlaying` and `track.scrobble`.
- Persist session and expose login state in UI.

3. Real Player Input
- Implement Apple Music and Spotify listeners.
- Normalize metadata to `Track` model.
- Validate transition handling (start/pause/resume/stop).

4. Reliable Scrobbling
- Scrobble thresholds/rules parity with legacy behavior.
- Local queue persistence and retry policy.
- Connection recovery and background submission.

5. UX Parity + Modernization
- Main window parity for now playing/scrobbles/profile basics.
- Settings and account management.
- Native notifications and polished menu bar flow.

6. Hardening + Release
- Unit/integration tests for API/signature/session/scrobble queue.
- Logging/diagnostics screen.
- Packaging/signing/notarization pipeline.

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
