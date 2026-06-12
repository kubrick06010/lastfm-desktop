import Foundation

extension LastfmAPIClient {
    func fetchTrackDetails(artist: String, track: String) async throws -> LastfmTrackDetails {
        var params: [String: String] = [
            "method": "track.getInfo",
            "artist": artist,
            "track": track,
            "autocorrect": "1"
        ]
        if let user = session?.name, !user.isEmpty {
            params["username"] = user
        }

        let payload: [String: Any]
        do {
            // Prefer the public read endpoint for metadata. It consistently returns
            // stats/artwork for read-only methods and avoids needless dependence on
            // the signed POST session path.
            payload = try await sendPublicRead(
                params: params,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
        } catch let LastfmAPIError.api(code, _) where code == 6 {
            return LastfmTrackDetails(
                name: track,
                artist: artist,
                album: nil,
                imageURL: nil,
                listeners: nil,
                playcount: nil,
                userPlaycount: nil,
                url: nil,
                summary: "No detailed metadata available for this track.",
                tags: []
            )
        } catch {
            var signedParams = params
            payload = try await send(
                params: &signedParams,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
        }
        guard let trackData = payload["track"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        return LastfmTrackDetails(
            name: firstString(trackData["name"]) ?? track,
            artist: firstString(trackData["artist"]) ?? artist,
            album: firstString(trackData["album"]),
            imageURL: imageURL((trackData["album"] as? [String: Any])?["image"]) ?? imageURL(trackData["image"]),
            listeners: firstInt(trackData["listeners"]),
            playcount: firstInt(trackData["playcount"]),
            userPlaycount: firstInt(trackData["userplaycount"]),
            url: firstString(trackData["url"]),
            summary: firstString((trackData["wiki"] as? [String: Any])?["summary"]),
            tags: tagNames(from: (trackData["toptags"] as? [String: Any])?["tag"])
        )
    }

    func fetchArtistDetails(artist: String) async throws -> LastfmArtistDetails {
        var params: [String: String] = [
            "method": "artist.getInfo",
            "artist": artist,
            "autocorrect": "1"
        ]
        if let user = session?.name, !user.isEmpty {
            params["username"] = user
        }

        let payload: [String: Any]
        do {
            // Prefer the public read endpoint for metadata. It consistently returns
            // stats/artwork for read-only methods and avoids needless dependence on
            // the signed POST session path.
            payload = try await sendPublicRead(
                params: params,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
        } catch let LastfmAPIError.api(code, _) where code == 6 {
            return LastfmArtistDetails(
                name: artist,
                imageURL: nil,
                listeners: nil,
                playcount: nil,
                userPlaycount: nil,
                url: nil,
                summary: "No detailed metadata available for this artist.",
                tags: [],
                similarArtists: []
            )
        } catch {
            var signedParams = params
            payload = try await send(
                params: &signedParams,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
        }
        guard let artistData = payload["artist"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        let supplement = await scrapeArtistImageSupplement(
            pageURL: firstString(artistData["url"]),
            similarArtists: users(from: (artistData["similar"] as? [String: Any])?["artist"]).compactMap { item in
                guard let name = firstString(item["name"]) else { return nil }
                return (name, firstString(item["url"]))
            }
        )

        return LastfmArtistDetails(
            name: firstString(artistData["name"]) ?? artist,
            imageURL: imageURL(artistData["image"]) ?? supplement.imageURL,
            listeners: firstInt(artistData["stats"], key: "listeners"),
            playcount: firstInt(artistData["stats"], key: "playcount"),
            userPlaycount: firstInt(artistData["stats"], key: "userplaycount"),
            url: firstString(artistData["url"]),
            summary: firstString((artistData["bio"] as? [String: Any])?["summary"]),
            tags: tagNames(from: (artistData["tags"] as? [String: Any])?["tag"]),
            similarArtists: users(from: (artistData["similar"] as? [String: Any])?["artist"]).map { item in
                let name = firstString(item["name"]) ?? "Unknown Artist"
                return LastfmSimilarArtist(
                    id: name,
                    name: name,
                    imageURL: imageURL(item["image"]) ?? supplement.similarArtistImages[name],
                    url: firstString(item["url"])
                )
            }
        )
    }

    func fetchSimilarTracks(artist: String, track: String, limit: Int = 8) async throws -> [LastfmSimilarTrack] {
        let cappedLimit = min(max(1, limit), 24)
        let params: [String: String] = [
            "method": "track.getSimilar",
            "artist": artist,
            "track": track,
            "limit": String(cappedLimit),
            "autocorrect": "1"
        ]

        do {
            let payload = try await sendPublicRead(
                params: params,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
            guard let similarData = payload["similartracks"] as? [String: Any] else {
                return []
            }
            return Array(users(from: similarData["track"]).prefix(cappedLimit)).map { item in
                let name = firstString(item["name"]) ?? "Unknown Track"
                let artistName = firstString((item["artist"] as? [String: Any])?["name"]) ?? firstString(item["artist"]) ?? "Unknown Artist"
                return LastfmSimilarTrack(
                    id: "\(artistName)|\(name)",
                    name: name,
                    artist: artistName,
                    imageURL: imageURL(item["image"]),
                    url: firstString(item["url"])
                )
            }
        } catch {
            return try await scrapeSimilarTracksFromWeb(artist: artist, track: track, limit: cappedLimit)
        }
    }

    func fetchSimilarAlbums(artist: String, album: String, limit: Int = 8) async throws -> [LastfmSimilarAlbum] {
        try await scrapeSimilarAlbumsFromWeb(artist: artist, album: album, limit: min(max(1, limit), 12))
    }

    func scrapeSimilarTracksFromWeb(artist: String, track: String, limit: Int) async throws -> [LastfmSimilarTrack] {
        let pageURL = try lastfmTrackPageURL(artist: artist, track: track)
        let html = try await fetchPublicHTML(from: pageURL)
        let pattern = #"<li class="[^"]*track-similar-tracks-item-wrap[^"]*"[\s\S]*?<h3 class="track-similar-tracks-item-name"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>[\s\S]*?<p class="track-similar-tracks-item-artist"[\s\S]*?<a[^>]*>(.*?)</a>[\s\S]*?<span class="track-similar-tracks-item-image cover-art">[\s\S]*?<img[^>]*src="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var output: [LastfmSimilarTrack] = []

        for match in regex.matches(in: html, options: [], range: range) {
            guard match.numberOfRanges >= 5,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let nameRange = Range(match.range(at: 2), in: html),
                  let artistRange = Range(match.range(at: 3), in: html),
                  let imageRange = Range(match.range(at: 4), in: html) else {
                continue
            }
            let name = htmlDecodedString(String(html[nameRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            let artistName = htmlDecodedString(String(html[artistRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !artistName.isEmpty else { continue }
            let rawURL = String(html[urlRange])
            let resolvedURL = rawURL.hasPrefix("http") ? rawURL : "https://www.last.fm\(rawURL)"
            output.append(
                LastfmSimilarTrack(
                    id: "\(artistName)|\(name)",
                    name: name,
                    artist: artistName,
                    imageURL: normalizedImageCandidate(String(html[imageRange])),
                    url: resolvedURL
                )
            )
            if output.count >= limit {
                break
            }
        }
        return output
    }

    func scrapeSimilarAlbumsFromWeb(artist: String, album: String, limit: Int) async throws -> [LastfmSimilarAlbum] {
        let pageURL = try lastfmAlbumPageURL(artist: artist, album: album)
        let html = try await fetchPublicHTML(from: pageURL)
        let pattern = #"<li class="[^"]*similar-albums-item-wrap[^"]*"[\s\S]*?<h3 class="similar-albums-item-name"[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>[\s\S]*?<p class="similar-albums-item-artist"[\s\S]*?<a[^>]*>(.*?)</a>[\s\S]*?<span class="similar-albums-item-image cover-art">[\s\S]*?<img[^>]*src="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        var output: [LastfmSimilarAlbum] = []

        for match in regex.matches(in: html, options: [], range: range) {
            guard match.numberOfRanges >= 5,
                  let urlRange = Range(match.range(at: 1), in: html),
                  let nameRange = Range(match.range(at: 2), in: html),
                  let artistRange = Range(match.range(at: 3), in: html),
                  let imageRange = Range(match.range(at: 4), in: html) else {
                continue
            }
            let name = htmlDecodedString(String(html[nameRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            let artistName = htmlDecodedString(String(html[artistRange])).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !artistName.isEmpty else { continue }
            let rawURL = String(html[urlRange])
            let resolvedURL = rawURL.hasPrefix("http") ? rawURL : "https://www.last.fm\(rawURL)"
            output.append(
                LastfmSimilarAlbum(
                    id: "\(artistName)|\(name)",
                    name: name,
                    artist: artistName,
                    imageURL: normalizedImageCandidate(String(html[imageRange])),
                    url: resolvedURL
                )
            )
            if output.count >= limit {
                break
            }
        }
        return output
    }

    func lastfmTrackPageURL(artist: String, track: String) throws -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let artistPath = artist.addingPercentEncoding(withAllowedCharacters: allowed) ?? artist
        let trackPath = track.addingPercentEncoding(withAllowedCharacters: allowed) ?? track
        guard let url = URL(string: "https://www.last.fm/music/\(artistPath)/_/\(trackPath)") else {
            throw LastfmAPIError.invalidResponse
        }
        return url
    }

    func lastfmAlbumPageURL(artist: String, album: String) throws -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let artistPath = artist.addingPercentEncoding(withAllowedCharacters: allowed) ?? artist
        let albumPath = album.addingPercentEncoding(withAllowedCharacters: allowed) ?? album
        guard let url = URL(string: "https://www.last.fm/music/\(artistPath)/\(albumPath)") else {
            throw LastfmAPIError.invalidResponse
        }
        return url
    }

    func scrapeArtistImageSupplement(
        pageURL: String?,
        similarArtists: [(name: String, url: String?)]
    ) async -> ArtistImageSupplement {
        guard let pageURL,
              let mainURL = URL(string: pageURL) else {
            return ArtistImageSupplement(imageURL: nil, similarArtistImages: [:])
        }

        let mainImage = await scrapeOpenGraphImage(from: mainURL)
        var similarImages: [String: String] = [:]

        for item in similarArtists.prefix(4) {
            guard let urlString = item.url,
                  let url = URL(string: urlString),
                  let image = await scrapeOpenGraphImage(from: url) else {
                continue
            }
            similarImages[item.name] = image
        }

        return ArtistImageSupplement(imageURL: mainImage, similarArtistImages: similarImages)
    }

    func scrapeOpenGraphImage(from url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("LastfmModern/1.0", forHTTPHeaderField: "User-Agent")

        guard let (data, _) = try? await activeURLSession.data(for: request),
              let html = String(data: data, encoding: .utf8),
              !html.isEmpty else {
            return nil
        }

        let patterns = [
            #"<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']"#,
            #"<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            guard let match = regex.firstMatch(in: html, options: [], range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: html) else {
                continue
            }
            if let candidate = normalizedImageCandidate(String(html[valueRange])) {
                return candidate
            }
        }

        return nil
    }
}
