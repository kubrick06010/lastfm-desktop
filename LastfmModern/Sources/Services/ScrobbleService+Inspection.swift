import Foundation

@MainActor
extension ScrobbleService {
    func inspect(track: String, artist: String) async {
        let item = LastfmRecentScrobble(
            id: "\(artist)|\(track)|inspect",
            track: track,
            artist: artist,
            album: nil,
            imageURL: nil,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false
        )
        await inspect(scrobble: item)
    }

    func inspect(scrobble: LastfmRecentScrobble) async {
        guard isAuthenticated else {
            inspectStatus = "Sign in to inspect tracks"
            inspectedTrackDetails = nil
            inspectedArtistDetails = nil
            return
        }
        inspectStatus = "Loading detail..."
        lastAPIError = nil
        lastRecoveryHint = nil
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectedSimilarTracks = []
        inspectedSimilarAlbums = []

        var loadedAnything = false
        var degraded = false
        let isArtistOnlyInspection = scrobble.id.hasPrefix("deep-artist-")
        let isAlbumInspection = scrobble.id.hasPrefix("deep-album-")

        if !isArtistOnlyInspection && !isAlbumInspection {
            do {
                inspectedTrackDetails = try await fetchWithRetry {
                    try await self.api.fetchTrackDetails(artist: scrobble.artist, track: scrobble.track)
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedTrackDetails = LastfmTrackDetails(
                    name: scrobble.track,
                    artist: scrobble.artist,
                    album: scrobble.album,
                    imageURL: scrobble.imageURL,
                    listeners: nil,
                    playcount: nil,
                    userPlaycount: nil,
                    url: scrobble.url,
                    summary: "Detailed track metadata is temporarily unavailable.",
                    tags: []
                )
                loadedAnything = true
                degraded = true
                handle(error: error)
            }

            do {
                inspectedSimilarTracks = try await fetchWithRetry {
                    try await self.api.fetchSimilarTracks(artist: scrobble.artist, track: scrobble.track, limit: 8)
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedSimilarTracks = []
                degraded = true
                handle(error: error)
            }
        }

        if isAlbumInspection {
            do {
                inspectedSimilarAlbums = try await fetchWithRetry {
                    try await self.api.fetchSimilarAlbums(
                        artist: scrobble.artist,
                        album: scrobble.album ?? scrobble.track,
                        limit: 8
                    )
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedSimilarAlbums = []
                degraded = true
                handle(error: error)
            }
        }

        do {
            inspectedArtistDetails = try await fetchWithRetry {
                try await self.api.fetchArtistDetails(artist: scrobble.artist)
            }
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            inspectedArtistDetails = LastfmArtistDetails(
                name: scrobble.artist,
                imageURL: nil,
                listeners: nil,
                playcount: nil,
                userPlaycount: nil,
                url: nil,
                summary: "Artist biography and stats are temporarily unavailable.",
                tags: [],
                similarArtists: []
            )
            loadedAnything = true
            degraded = true
            handle(error: error)
        }

        if loadedAnything {
            inspectStatus = degraded ? "Loaded (limited)" : "Loaded"
        } else {
            inspectStatus = "Failed to load detail"
        }
    }

    func fetchWithRetry<T>(_ work: @escaping () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard shouldRetryInspection(error) else {
                throw error
            }
            await sleepFunction(550_000_000)
            return try await work()
        }
    }

    func shouldRetryInspection(_ error: Error) -> Bool {
        if let apiError = error as? LastfmAPIError {
            switch apiError {
            case .networkUnavailable, .transport, .rateLimited:
                return true
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
    }

    func clearInspection() {
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectStatus = "Select a scrobble to inspect"
    }

    func love(scrobble: LastfmRecentScrobble) async {
        do {
            try await api.love(track: scrobble.track, artist: scrobble.artist)
            if let index = latestScrobbles.firstIndex(where: { $0.id == scrobble.id }) {
                let item = latestScrobbles[index]
                latestScrobbles[index] = LastfmRecentScrobble(
                    id: item.id,
                    track: item.track,
                    artist: item.artist,
                    album: item.album,
                    imageURL: item.imageURL,
                    url: item.url,
                    loved: true,
                    playedAt: item.playedAt,
                    nowPlaying: item.nowPlaying
                )
            }
        } catch {
            handle(error: error)
        }
    }

    func toggleLove(scrobble: LastfmRecentScrobble) async {
        do {
            if scrobble.loved {
                try await api.unlove(track: scrobble.track, artist: scrobble.artist)
                updateLovedState(for: scrobble.id, loved: false)
            } else {
                try await api.love(track: scrobble.track, artist: scrobble.artist)
                updateLovedState(for: scrobble.id, loved: true)
            }
        } catch {
            handle(error: error)
        }
    }

    func updateLovedState(for id: String, loved: Bool) {
        guard let index = latestScrobbles.firstIndex(where: { $0.id == id }) else { return }
        let item = latestScrobbles[index]
        latestScrobbles[index] = LastfmRecentScrobble(
            id: item.id,
            track: item.track,
            artist: item.artist,
            album: item.album,
            imageURL: item.imageURL,
            url: item.url,
            loved: loved,
            playedAt: item.playedAt,
            nowPlaying: item.nowPlaying
        )
    }
}
