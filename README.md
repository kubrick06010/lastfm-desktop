# lastfm-desktop

> [!IMPORTANT]
> This repository is archived and will not receive further updates.
> The code remains available for historical reference only.

This repository now contains:

1. The legacy Qt desktop client (historical codebase).
2. `LastfmModern`, a modern macOS SwiftUI client that was focused on Last.fm scrobbling workflows.
   - Uses a single main-window model (plus menu bar controls) for lower overhead.
   - Uses built-in app credentials for normal end-user sign-in.

## Final development target: `LastfmModern` (macOS)

This was the final development target before the repository was archived.

- Project: `LastfmModern/LastfmModern.xcodeproj`
- Platform: macOS (Xcode)
- Xcode: currently validated with Xcode 26.5. The generated project may require a recent Xcode version.
- Runtime mode:
  - Live Last.fm API mode with built-in app credentials (default end-user flow).
  - Optional developer override via environment variables.

See full app documentation in [LastfmModern/README.md](LastfmModern/README.md).

Final UI direction worth noting:
- The right-hand detail inspector is contextual by entity type and no longer reuses artist-only related content for tracks/albums.
- The inspector uses adaptive breakpoints for narrow, regular, and wide widths.

## Quick start (macOS)

1. Open and run from Xcode:

```bash
open LastfmModern/LastfmModern.xcodeproj
```

2. Sign in with your Last.fm username and password inside the app.

3. Optional (development override only): set custom API credentials in your shell before launching:

```bash
export LASTFM_API_KEY="your_api_key"
export LASTFM_SHARED_SECRET="your_shared_secret"
```

4. Run tests from terminal:

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
- `liblastfm/`: optional local reference checkout of `lastfm/liblastfm` kept out of version control.
- `app/`, `common/`, `plugins/`, `lib/`: legacy Qt desktop client code.

## Engineering practices

Future work should follow [docs/ENGINEERING_PRACTICES.md](docs/ENGINEERING_PRACTICES.md).
The practices adapt the OpenScrobbler workflow to this repository: `LastfmModern`
is the active app, legacy Qt code is maintained conservatively, and current
oversized Swift files should be reduced through incremental, tested extraction.

## Legacy Qt client status

The root legacy client build instructions in older revisions targeted Qt4-era toolchains and are kept here as historical context, but are not the primary path for current work.

## Security note

Do not commit API key/shared secret values into tracked files. Prefer environment variables (`LASTFM_API_KEY`, `LASTFM_SHARED_SECRET`) only for developer overrides.
