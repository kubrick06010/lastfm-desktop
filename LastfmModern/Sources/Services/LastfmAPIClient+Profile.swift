import Foundation

extension LastfmAPIClient {
    func fetchUserProfile() async throws -> LastfmUserProfile {
        let user = try requireSessionName()
        var params: [String: String] = [
            "method": "user.getInfo",
            "user": user
        ]

        let payload = try await send(params: &params, cachePolicy: .ttl(seconds: 300, staleFallbackSeconds: 86_400)).payload
        guard let userData = payload["user"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        return LastfmUserProfile(
            name: firstString(userData["name"]) ?? user,
            realname: firstString(userData["realname"]),
            playcount: firstInt(userData["playcount"]),
            artistCount: firstInt(userData["artist_count"]),
            trackCount: firstInt(userData["track_count"]),
            albumCount: firstInt(userData["album_count"]),
            country: firstString(userData["country"]),
            url: firstString(userData["url"]),
            imageURL: imageURL(userData["image"]),
            registeredAt: dateFromUnix(firstString((userData["registered"] as? [String: Any])?["unixtime"])),
            accountType: firstString(userData["type"])
        )
    }

    func fetchRecentScrobbles(limit: Int = 25) async throws -> [LastfmRecentScrobble] {
        let user = try requireSessionName()
        let cappedLimit = min(max(1, limit), 2_000)
        let pageSize = min(200, cappedLimit)
        var page = 1
        var totalPages: Int?
        let maxRequestedPages = Int(ceil(Double(cappedLimit) / Double(pageSize)))
        var allTracks: [[String: Any]] = []

        while page <= maxRequestedPages {
            if let totalPages, page > totalPages {
                break
            }
            var params: [String: String] = [
                "method": "user.getRecentTracks",
                "user": user,
                "limit": String(pageSize),
                "page": String(page),
                "extended": "1"
            ]

            let payload = try await send(params: &params, cachePolicy: .ttl(seconds: 20, staleFallbackSeconds: 0)).payload
            guard let recent = payload["recenttracks"] as? [String: Any] else {
                throw LastfmAPIError.invalidResponse
            }

            if totalPages == nil,
               let attr = recent["@attr"] as? [String: Any],
               let parsedPages = firstInt(attr["totalPages"]),
               parsedPages > 0 {
                totalPages = parsedPages
            }

            let tracksRaw = recent["track"]
            let tracksArray: [[String: Any]]
            if let array = tracksRaw as? [[String: Any]] {
                tracksArray = array
            } else if let single = tracksRaw as? [String: Any] {
                tracksArray = [single]
            } else {
                tracksArray = []
            }

            if tracksArray.isEmpty {
                break
            }
            allTracks.append(contentsOf: tracksArray)
            if allTracks.count >= cappedLimit {
                break
            }
            page += 1
        }

        return Array(allTracks.prefix(cappedLimit)).map { item in
            let attr = item["@attr"] as? [String: Any]
            let dateValue = item["date"] as? [String: Any]
            let uts = firstString(dateValue?["uts"])
            let playedAt = uts.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
            let trackName = firstString(item["name"]) ?? "Unknown Track"
            let artistName = firstString(item["artist"]) ?? "Unknown Artist"
            let albumName = firstString(item["album"])
            let imageURL = imageURL(item["image"])
            let url = firstString(item["url"])
            let loved = firstString(item["loved"]) == "1"
            let nowPlaying = boolValue(attr?["nowplaying"])
            return LastfmRecentScrobble(
                id: "\(artistName)|\(trackName)|\(uts ?? UUID().uuidString)",
                track: trackName,
                artist: artistName,
                album: albumName,
                imageURL: imageURL,
                url: url,
                loved: loved,
                playedAt: playedAt,
                nowPlaying: nowPlaying
            )
        }
    }

    func fetchLovedTracksCount() async throws -> Int? {
        let user = try requireSessionName()
        var params: [String: String] = [
            "method": "user.getLovedTracks",
            "user": user,
            "limit": "1"
        ]
        let payload = try await send(
            params: &params,
            cachePolicy: .ttl(seconds: 600, staleFallbackSeconds: 86_400)
        ).payload
        guard let loved = payload["lovedtracks"] as? [String: Any],
              let attr = loved["@attr"] as? [String: Any] else {
            return nil
        }
        return firstInt(attr["total"])
    }

    func fetchTopArtists(period: LastfmTopArtistPeriod, limit: Int = 10) async throws -> [LastfmTopArtist] {
        let user = try requireSessionName()
        var params: [String: String] = [
            "method": "user.getTopArtists",
            "user": user,
            "limit": String(max(1, limit)),
            "period": period.rawValue
        ]

        let payload = try await send(
            params: &params,
            cachePolicy: .ttl(seconds: 600, staleFallbackSeconds: 86_400)
        ).payload
        guard let topArtists = payload["topartists"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }
        return users(from: topArtists["artist"]).map { artist in
            let name = firstString(artist["name"]) ?? "Unknown Artist"
            return LastfmTopArtist(
                id: "\(period.rawValue)-\(name)",
                name: name,
                playcount: firstInt(artist["playcount"]),
                imageURL: imageURL(artist["image"]),
                url: firstString(artist["url"])
            )
        }
    }

    func fetchGlobalTopArtists(limit: Int = 50) async throws -> [String] {
        let cappedLimit = min(max(1, limit), 1000)
        let perPage = min(200, cappedLimit)
        let pages = Int(ceil(Double(cappedLimit) / Double(perPage)))

        var names: [String] = []
        var seen = Set<String>()
        for page in 1...max(1, pages) {
            var params: [String: String] = [
                "method": "chart.getTopArtists",
                "limit": String(perPage),
                "page": String(page)
            ]

            let payload = try await send(
                params: &params,
                cachePolicy: .ttl(seconds: 3600, staleFallbackSeconds: 86_400)
            ).payload
            guard let artistsContainer = payload["artists"] as? [String: Any] else {
                throw LastfmAPIError.invalidResponse
            }

            let batch = users(from: artistsContainer["artist"]).compactMap {
                firstString($0["name"])
            }
            if batch.isEmpty {
                break
            }

            for name in batch where names.count < cappedLimit {
                let key = name.lowercased()
                if seen.insert(key).inserted {
                    names.append(name)
                }
            }

            if names.count >= cappedLimit {
                break
            }
        }
        return names
    }
}
