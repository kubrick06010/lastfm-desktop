import Foundation

extension LastfmAPIClient {
    func nowPlaying(_ track: Track) async throws {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "track.updateNowPlaying",
            "artist": track.artist,
            "track": track.title,
            "sk": sk,
            "duration": String(Int(track.duration))
        ]
        if let album = track.album, !album.isEmpty {
            params["album"] = album
        }
        _ = try await send(params: &params, cachePolicy: .none)
    }

    func scrobble(_ track: Track) async throws {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "track.scrobble",
            "artist": track.artist,
            "track": track.title,
            "timestamp": String(Int(track.startedAt.timeIntervalSince1970)),
            "sk": sk
        ]
        if let album = track.album, !album.isEmpty {
            params["album"] = album
        }
        _ = try await send(params: &params, cachePolicy: .none)
    }

    func love(track: String, artist: String) async throws {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "track.love",
            "track": track,
            "artist": artist,
            "sk": sk
        ]
        _ = try await send(params: &params, cachePolicy: .none)
    }

    func unlove(track: String, artist: String) async throws {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "track.unlove",
            "track": track,
            "artist": artist,
            "sk": sk
        ]
        _ = try await send(params: &params, cachePolicy: .none)
    }
}
