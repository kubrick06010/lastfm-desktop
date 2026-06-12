import Foundation

extension LastfmAPIClient {

    func fetchFriendsListening(limit: Int = 50) async throws -> [LastfmFriendListening] {
        let user = try requireSessionName()
        let cappedLimit = min(max(1, limit), 1000)
        let pageSize = min(50, cappedLimit)
        var collected: [LastfmFriendListening] = []
        var page = 1
        var totalPages: Int?
        let requestedMaxPages = Int(ceil(Double(cappedLimit) / Double(pageSize)))

        while page <= requestedMaxPages {
            if let totalPages, page > totalPages {
                break
            }
            var params: [String: String] = [
                "method": "user.getFriends",
                "user": user,
                "recenttracks": "1",
                "limit": String(pageSize),
                "page": String(page)
            ]

            let payload: [String: Any]
            do {
                payload = try await send(
                    params: &params,
                    cachePolicy: .ttl(seconds: 20, staleFallbackSeconds: 0)
                ).payload
            } catch let LastfmAPIError.api(code, _) where code == 6 {
                // "no such page" can happen when requested pages exceed totalPages.
                if page > 1 {
                    break
                }
                throw LastfmAPIError.api(code: code, message: "no such page")
            }

            guard let friendsData = payload["friends"] as? [String: Any] else {
                throw LastfmAPIError.invalidResponse
            }
            if totalPages == nil,
               let attr = friendsData["@attr"] as? [String: Any],
               let parsed = firstInt(attr["totalPages"]),
               parsed > 0 {
                totalPages = parsed
            }

            let usersArray = users(from: friendsData["user"])
            if usersArray.isEmpty {
                break
            }

            collected.append(contentsOf: usersArray.map { user in
                let name = firstString(user["name"]) ?? "Unknown User"
                let realname = firstString(user["realname"])
                let country = firstString(user["country"])
                let isSubscriber = boolValue(user["subscriber"])
                let accountType = firstString(user["type"])
                let avatarURL = imageURL(user["image"])
                let recentTrack = recentTrackObject(user["recenttrack"])
                let track = firstString(recentTrack?["name"])
                let artist = firstString(recentTrack?["artist"])
                let imageURL = imageURL(recentTrack?["image"])
                let attr = recentTrack?["@attr"] as? [String: Any]
                let date = recentTrack?["date"] as? [String: Any]
                let playedAt = firstString(date?["uts"]).flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
                let nowPlaying = boolValue(attr?["nowplaying"]) || (recentTrack != nil && playedAt == nil)

                return LastfmFriendListening(
                    id: name,
                    user: name,
                    realname: realname,
                    country: country,
                    isSubscriber: isSubscriber,
                    accountType: accountType,
                    avatarURL: avatarURL,
                    track: track,
                    artist: artist,
                    imageURL: imageURL,
                    playedAt: playedAt,
                    nowPlaying: nowPlaying
                )
            })

            if collected.count >= cappedLimit {
                break
            }
            page += 1
        }
        var deduped: [String: LastfmFriendListening] = [:]
        for friend in collected {
            let key = friend.user.lowercased()
            guard let existing = deduped[key] else {
                deduped[key] = friend
                continue
            }
            if friend.nowPlaying && !existing.nowPlaying {
                deduped[key] = friend
                continue
            }
            let lhs = friend.playedAt ?? .distantPast
            let rhs = existing.playedAt ?? .distantPast
            if lhs > rhs {
                deduped[key] = friend
            }
        }

        var merged = deduped.values.sorted {
            if $0.nowPlaying != $1.nowPlaying {
                return $0.nowPlaying && !$1.nowPlaying
            }
            let lhs = $0.playedAt ?? .distantPast
            let rhs = $1.playedAt ?? .distantPast
            if lhs != rhs {
                return lhs > rhs
            }
            return $0.user.localizedCaseInsensitiveCompare($1.user) == .orderedAscending
        }
        if merged.count > cappedLimit {
            merged = Array(merged.prefix(cappedLimit))
        }

        let candidates = merged
            .filter { !$0.nowPlaying }
            .sorted { ($0.playedAt ?? .distantPast) > ($1.playedAt ?? .distantPast) }
        let hydrationCap = min(120, candidates.count)
        let hydrationBatchSize = 25
        if hydrationCap > 0 {
            var freshByUser: [String: (track: String?, artist: String?, imageURL: String?, playedAt: Date?, nowPlaying: Bool)] = [:]
            let hydrationCandidates = Array(candidates.prefix(hydrationCap))
            for start in stride(from: 0, to: hydrationCandidates.count, by: hydrationBatchSize) {
                let end = min(start + hydrationBatchSize, hydrationCandidates.count)
                let batch = hydrationCandidates[start..<end]
                await withTaskGroup(of: (String, (track: String?, artist: String?, imageURL: String?, playedAt: Date?, nowPlaying: Bool)?).self) { group in
                    for friend in batch {
                        let user = friend.user
                        group.addTask {
                            let fresh = try? await self.fetchLatestFriendTrack(user: user)
                            return (user.lowercased(), fresh)
                        }
                    }
                    for await result in group {
                        if let fresh = result.1 {
                            freshByUser[result.0] = fresh
                        }
                    }
                }
            }
            merged = merged.map { friend in
                guard let fresh = freshByUser[friend.user.lowercased()] else {
                    return friend
                }
                return LastfmFriendListening(
                    id: friend.id,
                    user: friend.user,
                    realname: friend.realname,
                    country: friend.country,
                    isSubscriber: friend.isSubscriber,
                    accountType: friend.accountType,
                    avatarURL: friend.avatarURL,
                    track: fresh.track ?? friend.track,
                    artist: fresh.artist ?? friend.artist,
                    imageURL: fresh.imageURL ?? friend.imageURL,
                    playedAt: fresh.playedAt ?? friend.playedAt,
                    nowPlaying: fresh.nowPlaying
                )
            }
        }

        return merged.sorted {
            if $0.nowPlaying != $1.nowPlaying {
                return $0.nowPlaying && !$1.nowPlaying
            }
            let lhs = $0.playedAt ?? .distantPast
            let rhs = $1.playedAt ?? .distantPast
            if lhs != rhs {
                return lhs > rhs
            }
            return $0.user.localizedCaseInsensitiveCompare($1.user) == .orderedAscending
        }
    }

    func fetchNeighbours(limit: Int = 50) async throws -> [LastfmNeighbour] {
        let user = try requireSessionName()
        let cappedLimit = min(max(1, limit), 1000)
        let pageSize = min(200, cappedLimit)
        var collected: [LastfmNeighbour] = []
        var page = 1
        var totalPages: Int?
        let requestedMaxPages = Int(ceil(Double(cappedLimit) / Double(pageSize)))

        while page <= requestedMaxPages {
            if let totalPages, page > totalPages {
                break
            }

            var params: [String: String] = [
                "method": "user.getNeighbours",
                "user": user,
                "limit": String(pageSize),
                "page": String(page)
            ]

            let payload: [String: Any]
            do {
                payload = try await send(
                    params: &params,
                    cachePolicy: .ttl(seconds: 30, staleFallbackSeconds: 0)
                ).payload
            } catch let LastfmAPIError.api(code, message)
                where code == 3 && message.localizedCaseInsensitiveContains("invalid method") {
                // Last.fm has intermittently disabled user.getNeighbours on API.
                // Fallback to profile page scraping to keep neighbours usable.
                let scraped = try await scrapeNeighboursFromWeb(user: user, limit: cappedLimit)
                if !scraped.isEmpty {
                    return scraped
                }
                throw LastfmAPIError.api(code: code, message: message)
            }

            guard let neighboursData = payload["neighbours"] as? [String: Any] else {
                throw LastfmAPIError.invalidResponse
            }
            if totalPages == nil,
               let attr = neighboursData["@attr"] as? [String: Any],
               let parsed = firstInt(attr["totalPages"]),
               parsed > 0 {
                totalPages = parsed
            }

            let usersArray = users(from: neighboursData["user"])
            if usersArray.isEmpty {
                break
            }

            collected.append(contentsOf: usersArray.map { item in
                let user = firstString(item["name"]) ?? "Unknown User"
                let matchScore = firstString(item["match"]).flatMap(Double.init)
                return LastfmNeighbour(
                    id: user,
                    user: user,
                    realname: firstString(item["realname"]),
                    country: firstString(item["country"]),
                    isSubscriber: boolValue(item["subscriber"]),
                    accountType: firstString(item["type"]),
                    avatarURL: imageURL(item["image"]),
                    profileURL: firstString(item["url"]),
                    matchScore: matchScore
                )
            })

            if collected.count >= cappedLimit {
                break
            }
            page += 1
        }

        var deduped: [String: LastfmNeighbour] = [:]
        for neighbour in collected {
            let key = neighbour.user.lowercased()
            guard let existing = deduped[key] else {
                deduped[key] = neighbour
                continue
            }
            let lhs = neighbour.matchScore ?? 0
            let rhs = existing.matchScore ?? 0
            if lhs > rhs {
                deduped[key] = neighbour
            }
        }

        var result = Array(deduped.values)
        result.sort {
            let lhs = $0.matchScore ?? 0
            let rhs = $1.matchScore ?? 0
            if lhs != rhs {
                return lhs > rhs
            }
            return $0.user.localizedCaseInsensitiveCompare($1.user) == .orderedAscending
        }
        if result.count > cappedLimit {
            result = Array(result.prefix(cappedLimit))
        }
        if result.isEmpty {
            let scraped = try await scrapeNeighboursFromWeb(user: user, limit: cappedLimit)
            if !scraped.isEmpty {
                return scraped
            }
        }
        return result
    }

    func fetchFriendUsernames(user: String, limit: Int = 120) async throws -> [String] {
        let normalized = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let cappedLimit = min(max(1, limit), 300)
        let pageSize = min(100, cappedLimit)
        var collected: [String] = []
        var page = 1
        var totalPages: Int?
        let requestedMaxPages = Int(ceil(Double(cappedLimit) / Double(pageSize)))

        while page <= requestedMaxPages {
            if let totalPages, page > totalPages {
                break
            }
            var params: [String: String] = [
                "method": "user.getFriends",
                "user": normalized,
                "limit": String(pageSize),
                "page": String(page)
            ]

            let payload = try await send(
                params: &params,
                cachePolicy: .ttl(seconds: 600, staleFallbackSeconds: 86_400)
            ).payload

            guard let friendsData = payload["friends"] as? [String: Any] else {
                throw LastfmAPIError.invalidResponse
            }
            if totalPages == nil,
               let attr = friendsData["@attr"] as? [String: Any],
               let parsed = firstInt(attr["totalPages"]),
               parsed > 0 {
                totalPages = parsed
            }

            let usersArray = users(from: friendsData["user"])
            if usersArray.isEmpty {
                break
            }

            for item in usersArray {
                guard let name = firstString(item["name"]), !name.isEmpty else { continue }
                collected.append(name)
                if collected.count >= cappedLimit {
                    break
                }
            }
            if collected.count >= cappedLimit {
                break
            }
            page += 1
        }

        var seen: Set<String> = []
        var unique: [String] = []
        unique.reserveCapacity(collected.count)
        for name in collected {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            unique.append(name)
        }
        return unique
    }

    func fetchLatestFriendTrack(user: String) async throws -> (track: String?, artist: String?, imageURL: String?, playedAt: Date?, nowPlaying: Bool)? {
        var params: [String: String] = [
            "method": "user.getRecentTracks",
            "user": user,
            "limit": "1",
            "extended": "1"
        ]
        let payload = try await send(
            params: &params,
            cachePolicy: .ttl(seconds: 15, staleFallbackSeconds: 0)
        ).payload
        guard let recent = payload["recenttracks"] as? [String: Any] else {
            return nil
        }
        let tracks = users(from: recent["track"])
        guard let item = tracks.first else {
            return nil
        }
        let attr = item["@attr"] as? [String: Any]
        let dateValue = item["date"] as? [String: Any]
        let uts = firstString(dateValue?["uts"])
        let playedAt = uts.flatMap(TimeInterval.init).map(Date.init(timeIntervalSince1970:))
        return (
            track: firstString(item["name"]),
            artist: firstString(item["artist"]),
            imageURL: imageURL(item["image"]),
            playedAt: playedAt,
            nowPlaying: boolValue(attr?["nowplaying"]) || (playedAt == nil && firstString(item["name"]) != nil)
        )
    }

    func recentTrackObject(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let array = value as? [[String: Any]] {
            return array.first
        }
        return nil
    }

    func scrapeNeighboursFromWeb(user: String, limit: Int) async throws -> [LastfmNeighbour] {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encodedUser = user.addingPercentEncoding(withAllowedCharacters: allowed) ?? user
        guard let url = URL(string: "https://www.last.fm/user/\(encodedUser)/neighbours") else {
            return []
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue("LastfmModern/1.0", forHTTPHeaderField: "User-Agent")

        let data: Data
        do {
            let response = try await activeURLSession.data(for: request)
            data = response.0
        } catch {
            if let urlError = error as? URLError {
                switch urlError.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            return []
        }

        let pattern = #"<li class="[^"]*user-list-item(?![^"]*user-list-item-mobile-ad)[^"]*"[\s\S]*?<h4 class="user-list-name">[\s\S]*?<a[^>]*href="/user/([^"/?#]+)"[\s\S]*?</a>[\s\S]*?<img[^>]*src="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let percentRegex = try NSRegularExpression(pattern: #"([1-9]\d?|100)\s*%"#, options: [])
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        let sourceLower = user.lowercased()
        var seen: Set<String> = []
        var output: [LastfmNeighbour] = []
        output.reserveCapacity(min(limit, 120))

        for match in regex.matches(in: html, options: [], range: range) {
            guard match.numberOfRanges >= 3,
                  let userRange = Range(match.range(at: 1), in: html),
                  let avatarRange = Range(match.range(at: 2), in: html) else {
                continue
            }
            let rawUser = String(html[userRange])
            let parsedUser = rawUser.removingPercentEncoding ?? rawUser
            let trimmedUser = parsedUser.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUser.isEmpty else { continue }
            let lower = trimmedUser.lowercased()
            guard lower != sourceLower else { continue }
            guard seen.insert(lower).inserted else { continue }
            let avatar = normalizedImageCandidate(String(html[avatarRange]))
            let safeEncoded = trimmedUser.addingPercentEncoding(withAllowedCharacters: allowed) ?? trimmedUser
            let matchScore = extractedNeighbourMatch(from: html, match: match, percentRegex: percentRegex)
                ?? estimatedNeighbourMatch(rank: output.count, limit: limit)

            output.append(
                LastfmNeighbour(
                    id: trimmedUser,
                    user: trimmedUser,
                    realname: nil,
                    country: nil,
                    isSubscriber: false,
                    accountType: nil,
                    avatarURL: avatar,
                    profileURL: "https://www.last.fm/user/\(safeEncoded)",
                    matchScore: matchScore
                )
            )
            if output.count >= limit {
                break
            }
        }

        return output
    }

    func extractedNeighbourMatch(
        from html: String,
        match: NSTextCheckingResult,
        percentRegex: NSRegularExpression
    ) -> Double? {
        guard let rowRange = Range(match.range(at: 0), in: html) else {
            return nil
        }
        let rowHTML = String(html[rowRange])
        let rowNSRange = NSRange(rowHTML.startIndex..<rowHTML.endIndex, in: rowHTML)
        guard let percentMatch = percentRegex.firstMatch(in: rowHTML, options: [], range: rowNSRange),
              let valueRange = Range(percentMatch.range(at: 1), in: rowHTML),
              let percent = Double(rowHTML[valueRange]) else {
            return nil
        }
        return max(0, min(1, percent / 100.0))
    }

    func estimatedNeighbourMatch(rank: Int, limit: Int) -> Double {
        let boundedLimit = max(1, min(limit, 500))
        if boundedLimit == 1 {
            return 0.9
        }
        let normalized = Double(rank) / Double(boundedLimit - 1)
        // Neighbours are ordered by affinity on Last.fm, so rank is a
        // reasonable fallback score when explicit percentages are unavailable.
        return max(0.2, min(0.95, 0.95 - (normalized * 0.65)))
    }
}
