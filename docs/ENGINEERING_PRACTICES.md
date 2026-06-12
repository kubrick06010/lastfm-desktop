# lastfm-desktop Engineering Practices

This document is the working protocol for future changes in this repository.
Every implementation should leave the active app easier to understand, test,
and evolve than it was before the change.

## Product And Repository Direction

- Treat `LastfmModern` as the active product surface for new macOS work.
- Treat `app/`, `common/`, `plugins/`, and `lib/` as legacy Qt client code:
  maintain them conservatively, avoid broad rewrites, and keep behavioral
  changes narrow.
- Keep Last.fm scrobbling workflows reliable before adding surface-level UI.
- Preserve user account, queue, proxy, launch-at-login, and scrobble history
  behavior unless a change explicitly migrates it.
- Keep API credentials and local account state out of source control.

## Core Principles

- Make changes in narrow, reviewable slices.
- Read the nearest existing code before changing it.
- Keep files focused on one primary responsibility.
- Keep service, persistence, and parsing logic out of SwiftUI views unless the
  view is only coordinating calls on an injected object.
- Prefer explicit inputs and callbacks for UI components over reaching into
  global app state.
- Prefer structured parsing and typed models for stable Last.fm responses.
- Keep fallback behavior deterministic and covered by tests when Last.fm
  endpoint behavior varies.
- Verify behavior with a build, and run tests when service, model, queue,
  parsing, persistence, or important user-flow logic changes.

## Active SwiftUI Structure

Use this layout for new or moved `LastfmModern` code:

- `LastfmModern/Sources/App`: app entry point, scene wiring, app-level menus,
  menu bar integration, and lifecycle coordination.
- `LastfmModern/Sources/Domain`: small value types and domain models that do
  not know about UI or transport details.
- `LastfmModern/Sources/Services`: Last.fm API access, account storage, queue
  storage, player monitoring, proxy behavior, launch-at-login, normalization,
  and other non-UI application services.
- `LastfmModern/Sources/UI`: SwiftUI screens, shell layout, feature views, and
  reusable presentation components.
- `LastfmModern/Tests`: behavioral tests for services, parsing, signatures,
  normalization, queue behavior, and migration-sensitive flows.

When adding new UI, prefer feature-local files under `Sources/UI` instead of
expanding `ContentView.swift`. If a feature grows beyond a small view, create a
feature folder such as `Dashboard`, `Scrobbles`, `Profile`, `Friends`, `Queue`,
`Reports`, `Charts`, `Neighbours`, `Account`, or `Components`.

## Current State And Migration

The active app has been split into focused Swift files. Keep that structure
intact as new behavior lands:

1. Add new feature UI in a focused file or feature folder.
2. Keep `ContentView` focused on shell, navigation, modal state, and feature
   wiring.
3. Move reusable UI into `Sources/UI/Components` only when it is truly generic.
4. Keep Last.fm API behavior split by endpoint family, transport, and shared
   parsing helpers.
5. Keep scrobbling behavior split by account/session, inspection, refresh,
   social graph, and playback/queue coordination.
6. When a file approaches 600 lines, split it before adding unrelated behavior.

## File Size And Boundaries

- Prefer Swift files under 400 lines.
- A Swift file over 600 lines needs a reason and should be considered for
  splitting before adding more behavior.
- A view with multiple unrelated subviews should move those subviews into
  feature-local files.
- A service with multiple endpoint families should expose small methods and
  keep request/response models near the behavior they support.
- Reusable components should not depend on feature-specific state unless that
  state is passed in through small value types, bindings, or closures.

For legacy Qt code:

- Prefer small fixes in the existing module where the behavior already lives.
- Keep `.ui` layout changes paired with the corresponding widget/controller
  changes.
- Avoid modernizing whole subsystems unless the task is explicitly a migration.
- Preserve platform-specific `.mm`, `_mac`, `_win`, and `_linux` boundaries.

## State And Dependencies

- Use the narrowest state owner that fits the behavior.
- Keep app-wide services wired at the app shell level until a broader
  dependency-injection refactor is intentionally planned.
- Keep account, scrobble queue, and retry state in services or stores, not in
  presentation views.
- Keep sheet, inspector, and navigation state near the shell when it crosses
  feature boundaries.
- Pass user intents upward with closures such as `onOpen`, `onShare`,
  `onLove`, `onTag`, `onRetry`, or `onSelectAccount`.

## Testing Expectations

Add or update tests when changing:

- Last.fm request signing, authentication, or error mapping.
- API response parsing and fallback behavior.
- Player normalization and source filtering.
- Scrobble threshold, queueing, retry, or persistence behavior.
- Account storage, proxy behavior, launch-at-login wiring, or other
  migration-sensitive user flows.

Presentation-only changes may only need a build, but UI changes that move
behavior between views and services should keep the existing behavior covered.

## Editing Protocol

1. Read the nearest existing code before changing it.
2. Identify the feature boundary before adding new files.
3. Prefer extracting existing behavior unchanged before redesigning it.
4. Avoid unrelated refactors in the same change.
5. Update this document when we intentionally change architecture or workflow.
6. Run the relevant build or test command before handing off.

For active macOS work:

```bash
xcodebuild \
  -project LastfmModern/LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

For a faster compile check when tests are not needed:

```bash
xcodebuild \
  -project LastfmModern/LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Legacy Qt build commands depend on the historical Qt toolchain. When changing
legacy code, document the exact local command used, or say plainly when the
toolchain was unavailable.

## Review Checklist

- Does each changed file still have one clear responsibility?
- Did new behavior land near the feature or service it belongs to?
- Did we avoid growing any file past the documented size boundary?
- Are shared components generic enough to justify living in `Components`?
- Are user actions reachable through visible controls, menus, or keyboard paths
  where appropriate?
- Did service/model/parser changes get tests?
- Did the active app build or test command run successfully?
- Were credentials, local account state, DerivedData, and generated user files
  kept out of source control?
