# LastfmModern

Modern macOS Last.fm desktop client built with SwiftUI.

## Requirements

- macOS with Xcode installed.
- Last.fm API credentials (API key + shared secret) for live mode.

## Configuration

Set credentials in your shell before launching from Xcode:

```bash
export LASTFM_API_KEY="your_api_key"
export LASTFM_SHARED_SECRET="your_shared_secret"
```

If these are missing, the app starts in stub mode with mock data.

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
- Session persistence and startup validation.
- Now playing updates (`track.updateNowPlaying`) and queued scrobbling (`track.scrobble`).
- Retry scheduler with backoff for failed submissions.
- Scrobble progress visualization against threshold.
- Rich tabs:
  - `Dashboard`: now-playing context, cover art, artist summary, similar artists.
  - `Scrobbles`: filterable history, row actions (`love`, `tag search`, `open/share`), slide-in detail page.
  - `Profile`: avatar, subscriber badge, scrobble stats, loved count, top artists (week/overall) with progress bars.
  - `Friends`: filterable feed, avatars, track artwork, subscriber badges, now-playing emphasis.
  - `Queue` and `Account`.
- Detailed metadata integration:
  - `track.getInfo`
  - `artist.getInfo`
  - `user.getInfo`
  - `user.getRecentTracks`
  - `user.getFriends`
  - `user.getTopArtists`
  - `user.getLovedTracks`

## Notes and limitations

- Friends "listening now" depends on what Last.fm currently returns for your social graph and privacy settings.
- Some artists/tracks do not provide complete image or metadata; the app falls back gracefully.
- Keep API credentials out of source control; use environment variables only.
