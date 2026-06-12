# Contributing

Thanks for helping improve `lastfm-desktop`. Current development is focused on
`LastfmModern`, the macOS SwiftUI client. The legacy Qt client remains in the
repository for historical context and narrowly scoped maintenance.

Before making changes, read [docs/ENGINEERING_PRACTICES.md](docs/ENGINEERING_PRACTICES.md).
That document is the working protocol for architecture boundaries, file sizes,
testing expectations, and review checks.

## Local Setup

Requirements for active development:

- macOS with Xcode installed.
- No checked-in Last.fm API credentials. Built-in credentials are used for the
  normal app flow; optional developer overrides use environment variables.

Run the active app tests:

```bash
xcodebuild \
  -project LastfmModern/LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Run a compile-only check:

```bash
xcodebuild \
  -project LastfmModern/LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Pull Requests

Before opening a pull request:

- Keep the change focused on one behavior, feature area, or refactor slice.
- Avoid adding more unrelated behavior to known oversized files such as
  `ContentView.swift`, `LastfmAPI.swift`, and `ScrobbleService.swift`.
- Add or update tests for service parsing, request signing, player
  normalization, account state, scrobble queueing, retry behavior, or
  migration-sensitive flows.
- Run the relevant build or test command locally and include the result.
- Keep API keys, shared secrets, local account state, DerivedData, and
  user-specific Xcode state out of commits.

## Legacy Qt Changes

For changes under `app/`, `common/`, `plugins/`, or `lib/`, keep edits narrow
and document the exact Qt-era build or validation command used. If the required
toolchain is not available, say so explicitly in the handoff.
