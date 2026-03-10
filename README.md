# lastfm-desktop

This repository now contains:

1. The legacy Qt desktop client (historical codebase).
2. `LastfmModern`, a modern macOS SwiftUI client focused on Last.fm scrobbling workflows.
   - Uses a single main-window model (plus menu bar controls) for lower overhead.

## Active target: `LastfmModern` (macOS)

Use this for current development.

- Project: `LastfmModern/LastfmModern.xcodeproj`
- Platform: macOS (Xcode)
- Runtime mode:
  - Live Last.fm API mode with built-in app credentials (default end-user flow).
  - Optional developer override via environment variables.

See full app documentation in [LastfmModern/README.md](/Users/haa/Desktop/projects/lastfm-desktop/LastfmModern/README.md).

## Quick start (macOS)

1. Open and run from Xcode:

```bash
open LastfmModern/LastfmModern.xcodeproj
```

2. Optional (development override only): set custom API credentials in your shell:

```bash
export LASTFM_API_KEY="your_api_key"
export LASTFM_SHARED_SECRET="your_shared_secret"
```

3. Run tests from terminal:

```bash
xcodebuild \
  -project LastfmModern/LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Repository layout

- `LastfmModern/`: SwiftUI macOS app (active).
- `liblastfm/`: cloned `lastfm/liblastfm` library source.
- `app/`, `common/`, `plugins/`, `lib/`: legacy Qt desktop client code.

## Legacy Qt client status

The root legacy client build instructions in older revisions targeted Qt4-era toolchains and are kept here as historical context, but are not the primary path for current work.

## Security note

Do not commit API key/shared secret values into tracked files. Prefer environment variables (`LASTFM_API_KEY`, `LASTFM_SHARED_SECRET`).
