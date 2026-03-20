# LastfmModern

Modern macOS Last.fm desktop client built with SwiftUI.

## Requirements

- macOS with Xcode installed.

## Configuration

For end users, API credentials are handled internally (legacy desktop compatibility), so only Last.fm username/password are needed to sign in.

For development/testing, you can override credentials via environment variables:

```bash
export LASTFM_API_KEY="your_api_key"
export LASTFM_SHARED_SECRET="your_shared_secret"
```

These overrides are optional and not required for normal end-user sign-in.

## Build and test

```bash
xcodebuild \
  -project LastfmModern.xcodeproj \
  -scheme LastfmModern \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

## Implemented macOS features

- Last.fm authentication via `auth.getMobileSession`.
- Multi-account session persistence and startup validation.
- Now playing updates (`track.updateNowPlaying`) and queued scrobbling (`track.scrobble`).
- Retry scheduler with backoff for failed submissions.
- Scrobble progress visualization against threshold.
- Single main-window model (memory-friendly): the app reuses one primary window.
- Launch-at-login toggle backed by `SMAppService`.
- Proxy configuration (`Auto Detect`, `No Proxy`, `HTTP`, `SOCKS5`) wired into the networking layer.
- Rich tabs:
  - `Dashboard`: now-playing context, mood-reactive backdrop, cover art, artist summary, clickable tags, similar artists.
  - `Scrobbles`: filterable history, row actions (`love/unlove`, `tag`, `open/share`), slide-in detail page.
  - `Profile`: avatar (including animated GIF-capable rendering), subscriber badge, scrobble stats, loved count, top artists (week/overall) with progress bars.
  - `Friends`: filterable feed with hybrid activity mode (now playing + recently active), avatars, track artwork, subscriber badges.
  - `Queue`, `Reports`, `Charts`, `Neighbours`, and `Account`.
- Adaptive macOS shell behavior:
  - Dock icon can be toggled on/off (menu bar mode).
  - Menu bar extra includes scrobbling toggle, account context, now-playing artwork, and quick open actions.
  - Diagnostics are opened inside the main window flow (no extra app window scene).
- Detailed metadata integration:
  - `track.getInfo`
  - `artist.getInfo`
  - `user.getInfo`
  - `user.getRecentTracks`
  - `user.getFriends`
  - `user.getTopArtists`
  - `user.getLovedTracks`
- Contextual detail inspector behavior:
  - `Artist Detail` renders artist biography, stats, tags, and similar artists.
  - `Track Detail` renders track metadata plus similar tracks.
  - `Album Detail` renders album metadata plus similar albums.
  - The inspector adapts layout by available width instead of shrinking text indefinitely.

## Notes and limitations

- Browser playback from generic system media controls is not a supported scrobble source.
- VLC integration has been evaluated and is feasible, but is not implemented yet.
- Friends "listening now" depends on what Last.fm currently returns for your social graph and privacy settings.
- Hybrid friends mode includes now-playing users and recently active users (time-window based), so counts can differ from strict live-only views.
- Some artists/tracks do not provide complete image or metadata; the app falls back gracefully.
- Last.fm API behavior can vary by endpoint/account type; neighbour/compatibility data may require fallback logic.
- Keep API credentials out of source control when using override values.
