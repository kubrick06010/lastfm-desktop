import Foundation
import CryptoKit

enum LastfmSignature {
    static func make(params: [String: String], sharedSecret: String) -> String {
        let sorted = params.keys.sorted()
        let source = sorted.reduce(into: "") { partial, key in
            guard let value = params[key] else { return }
            partial += key + value
        } + sharedSecret

        let digest = Insecure.MD5.hash(data: Data(source.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

protocol LastfmAPI {
    var isConfigured: Bool { get }
    var isAuthenticated: Bool { get }
    var sessionUsername: String? { get }
    func authenticate(username: String, password: String) async throws -> LastfmSession
    func restoreSession(_ session: LastfmSession)
    func clearSession()
    func validateSession() async throws -> LastfmSessionValidation
    func nowPlaying(_ track: Track) async throws
    func scrobble(_ track: Track) async throws
    func love(track: String, artist: String) async throws
    func unlove(track: String, artist: String) async throws
    func fetchTrackDetails(artist: String, track: String) async throws -> LastfmTrackDetails
    func fetchArtistDetails(artist: String) async throws -> LastfmArtistDetails
    func fetchUserProfile() async throws -> LastfmUserProfile
    func fetchRecentScrobbles(limit: Int) async throws -> [LastfmRecentScrobble]
    func fetchFriendsListening(limit: Int) async throws -> [LastfmFriendListening]
    func fetchNeighbours(limit: Int) async throws -> [LastfmNeighbour]
    func fetchFriendUsernames(user: String, limit: Int) async throws -> [String]
    func fetchTopArtists(period: LastfmTopArtistPeriod, limit: Int) async throws -> [LastfmTopArtist]
    func fetchGlobalTopArtists(limit: Int) async throws -> [String]
    func fetchLovedTracksCount() async throws -> Int?
}

struct LastfmSession: Codable, Equatable {
    let name: String
    let key: String
}

struct LastfmAPIConfig {
    let apiKey: String
    let sharedSecret: String
    let endpoint: URL

    // Legacy desktop defaults from `lib/unicorn/UnicornCoreApplication.cpp`.
    private static let legacyDefaultAPIKey = "9e89b44de1ff37c5246ad0af18406454"
    private static let legacyDefaultSharedSecret = "147320ea9b8930fe196a4231da50ada4"

    static let userDefaultsAPIKey = "lastfm.apiKey"
    static let userDefaultsSharedSecret = "lastfm.sharedSecret"

    static func fromEnvironment(bundle: Bundle = .main, defaults: UserDefaults = .standard) -> LastfmAPIConfig? {
        let env = ProcessInfo.processInfo.environment
        let key = normalized(
            env["LASTFM_API_KEY"] ??
            bundle.object(forInfoDictionaryKey: "LASTFM_API_KEY") as? String ??
            defaults.string(forKey: userDefaultsAPIKey) ??
            legacyDefaultAPIKey
        )
        let secret = normalized(
            env["LASTFM_SHARED_SECRET"] ??
            bundle.object(forInfoDictionaryKey: "LASTFM_SHARED_SECRET") as? String ??
            defaults.string(forKey: userDefaultsSharedSecret) ??
            legacyDefaultSharedSecret
        )

        guard let key, !key.isEmpty, let secret, !secret.isEmpty else {
            return nil
        }

        return LastfmAPIConfig(
            apiKey: key,
            sharedSecret: secret,
            endpoint: URL(string: "https://ws.audioscrobbler.com/2.0/")!
        )
    }

    static func saveToDefaults(apiKey: String, sharedSecret: String, defaults: UserDefaults = .standard) {
        defaults.set(apiKey, forKey: userDefaultsAPIKey)
        defaults.set(sharedSecret, forKey: userDefaultsSharedSecret)
    }

    static func clearSavedCredentials(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: userDefaultsAPIKey)
        defaults.removeObject(forKey: userDefaultsSharedSecret)
    }

    private static func normalized(_ value: String?) -> String? {
        value?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct LastfmCapabilities: Equatable {
    let canScrobble: Bool
    let canUseRadio: Bool
    let isSubscriber: Bool
    let accountType: String?

    static let unknown = LastfmCapabilities(
        canScrobble: true,
        canUseRadio: false,
        isSubscriber: false,
        accountType: nil
    )
}

struct LastfmSessionValidation: Equatable {
    let isValid: Bool
    let checkedAt: Date
    let fromCache: Bool
    let capabilities: LastfmCapabilities
}

struct LastfmTrackDetails: Equatable {
    let name: String
    let artist: String
    let album: String?
    let imageURL: String?
    let listeners: Int?
    let playcount: Int?
    let userPlaycount: Int?
    let url: String?
    let summary: String?
    let tags: [String]
}

struct LastfmSimilarArtist: Equatable, Identifiable {
    let id: String
    let name: String
    let imageURL: String?
    let url: String?
}

struct LastfmArtistDetails: Equatable {
    let name: String
    let imageURL: String?
    let listeners: Int?
    let playcount: Int?
    let userPlaycount: Int?
    let url: String?
    let summary: String?
    let tags: [String]
    let similarArtists: [LastfmSimilarArtist]
}

struct LastfmUserProfile: Equatable {
    let name: String
    let realname: String?
    let playcount: Int?
    let artistCount: Int?
    let trackCount: Int?
    let albumCount: Int?
    let country: String?
    let url: String?
    let imageURL: String?
    let registeredAt: Date?
    let accountType: String?
}

struct LastfmRecentScrobble: Equatable, Identifiable {
    let id: String
    let track: String
    let artist: String
    let album: String?
    let imageURL: String?
    let url: String?
    let loved: Bool
    let playedAt: Date?
    let nowPlaying: Bool
}

struct LastfmFriendListening: Equatable, Identifiable {
    let id: String
    let user: String
    let realname: String?
    let country: String?
    let isSubscriber: Bool
    let accountType: String?
    let avatarURL: String?
    let track: String?
    let artist: String?
    let imageURL: String?
    let playedAt: Date?
    let nowPlaying: Bool
}

struct LastfmNeighbour: Equatable, Identifiable {
    let id: String
    let user: String
    let realname: String?
    let country: String?
    let isSubscriber: Bool
    let accountType: String?
    let avatarURL: String?
    let profileURL: String?
    let matchScore: Double?
}

enum LastfmTopArtistPeriod: String {
    case overall
    case week = "7day"
    case month = "1month"
    case year = "12month"
}

struct LastfmTopArtist: Equatable, Identifiable {
    let id: String
    let name: String
    let playcount: Int?
    let imageURL: String?
    let url: String?
}

enum LastfmAPIError: LocalizedError {
    case missingSession
    case invalidResponse
    case invalidCredentials
    case invalidSession
    case rateLimited(retryAfter: Int?)
    case networkUnavailable
    case transport
    case api(code: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .missingSession:
            return "Last.fm session is missing. Please sign in."
        case .invalidResponse:
            return "Unexpected response from Last.fm."
        case .invalidCredentials:
            return "Invalid Last.fm username or password."
        case .invalidSession:
            return "Last.fm session expired or invalid."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Rate limited by Last.fm. Retry in about \(retryAfter) seconds."
            }
            return "Rate limited by Last.fm."
        case .networkUnavailable:
            return "Network is unavailable."
        case .transport:
            return "Could not reach Last.fm."
        case let .api(code, message):
            return "Last.fm API error \(code): \(message)"
        }
    }

    var recoverySuggestion: String {
        switch self {
        case .missingSession, .invalidSession:
            return "Sign in again to refresh your Last.fm session."
        case .invalidCredentials:
            return "Verify your Last.fm credentials and try again."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "Wait \(retryAfter) seconds, then retry."
            }
            return "Wait a few minutes before retrying."
        case .networkUnavailable, .transport:
            return "Check network connectivity. Queued scrobbles will retry automatically."
        case .invalidResponse, .api:
            return "Retry later. If this persists, inspect Last.fm API status and credentials."
        }
    }
}

final class LastfmAPIClient: LastfmAPI {
    let isConfigured = true
    private(set) var isAuthenticated = false
    var sessionUsername: String? { session?.name }

    private let config: LastfmAPIConfig
    private let urlSession: URLSession
    private var session: LastfmSession?
    private var endpointCache: [String: EndpointCacheEntry] = [:]
    private let endpointCacheLock = NSLock()

    init(config: LastfmAPIConfig, urlSession: URLSession = .shared) {
        self.config = config
        self.urlSession = urlSession
    }

    func authenticate(username: String, password: String) async throws -> LastfmSession {
        var params: [String: String] = [
            "method": "auth.getMobileSession",
            "username": username,
            "password": password
        ]

        let payload = try await send(params: &params, cachePolicy: .none).payload
        guard
            let sessionData = payload["session"] as? [String: Any],
            let name = sessionData["name"] as? String,
            let key = sessionData["key"] as? String
        else {
            throw LastfmAPIError.invalidResponse
        }

        let newSession = LastfmSession(name: name, key: key)
        restoreSession(newSession)
        return newSession
    }

    func restoreSession(_ session: LastfmSession) {
        self.session = session
        isAuthenticated = true
    }

    func clearSession() {
        session = nil
        isAuthenticated = false
    }

    func validateSession() async throws -> LastfmSessionValidation {
        let sk = try requireSessionKey()
        var params: [String: String] = [
            "method": "user.getInfo",
            "sk": sk
        ]

        let response = try await send(
            params: &params,
            cachePolicy: .ttl(seconds: 300, staleFallbackSeconds: 86_400)
        )
        let payload = response.payload
        guard let user = payload["user"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        let subscriberRaw = (user["subscriber"] as? String) ?? (user["subscriber"] as? NSNumber)?.stringValue ?? "0"
        let isSubscriber = subscriberRaw == "1"
        let accountType = user["type"] as? String
        let capabilities = LastfmCapabilities(
            canScrobble: true,
            canUseRadio: isSubscriber,
            isSubscriber: isSubscriber,
            accountType: accountType
        )

        return LastfmSessionValidation(
            isValid: true,
            checkedAt: .now,
            fromCache: response.fromCache,
            capabilities: capabilities
        )
    }

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
            payload = try await send(params: &params, cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)).payload
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
            // Read-only metadata endpoints can fail under signed POST in some
            // edge cases. Retry via unsigned public GET to keep details usable.
            payload = try await sendPublicRead(
                params: params,
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
            payload = try await send(params: &params, cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)).payload
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
            // Read-only metadata endpoints can fail under signed POST in some
            // edge cases. Retry via unsigned public GET to keep details usable.
            payload = try await sendPublicRead(
                params: params,
                cachePolicy: .ttl(seconds: 900, staleFallbackSeconds: 86_400)
            ).payload
        }
        guard let artistData = payload["artist"] as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }

        return LastfmArtistDetails(
            name: firstString(artistData["name"]) ?? artist,
            imageURL: imageURL(artistData["image"]),
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
                    imageURL: imageURL(item["image"]),
                    url: firstString(item["url"])
                )
            }
        )
    }

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

    private func fetchLatestFriendTrack(user: String) async throws -> (track: String?, artist: String?, imageURL: String?, playedAt: Date?, nowPlaying: Bool)? {
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

    private func recentTrackObject(_ value: Any?) -> [String: Any]? {
        if let dict = value as? [String: Any] {
            return dict
        }
        if let array = value as? [[String: Any]] {
            return array.first
        }
        return nil
    }

    private func scrapeNeighboursFromWeb(user: String, limit: Int) async throws -> [LastfmNeighbour] {
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
            let response = try await urlSession.data(for: request)
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

    private func extractedNeighbourMatch(
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

    private func estimatedNeighbourMatch(rank: Int, limit: Int) -> Double {
        let boundedLimit = max(1, min(limit, 500))
        if boundedLimit == 1 {
            return 0.9
        }
        let normalized = Double(rank) / Double(boundedLimit - 1)
        // Neighbours are ordered by affinity on Last.fm, so rank is a
        // reasonable fallback score when explicit percentages are unavailable.
        return max(0.2, min(0.95, 0.95 - (normalized * 0.65)))
    }

    private func users(from value: Any?) -> [[String: Any]] {
        if let array = value as? [[String: Any]] {
            return array
        }
        if let single = value as? [String: Any] {
            return [single]
        }
        return []
    }

    private func tagNames(from value: Any?) -> [String] {
        users(from: value).compactMap { firstString($0["name"]) }
    }

    private func dateFromUnix(_ value: String?) -> Date? {
        guard let value, let unix = TimeInterval(value) else { return nil }
        return Date(timeIntervalSince1970: unix)
    }

    private func requireSessionKey() throws -> String {
        guard let key = session?.key else {
            throw LastfmAPIError.missingSession
        }
        return key
    }

    private func requireSessionName() throws -> String {
        guard let name = session?.name, !name.isEmpty else {
            throw LastfmAPIError.missingSession
        }
        return name
    }

    private func send(
        params: inout [String: String],
        cachePolicy: EndpointCachePolicy = .none
    ) async throws -> EndpointResponse {
        let originalParams = params
        let cacheKey = endpointCacheKey(params: originalParams)
        if let entry = cachedEntry(for: cacheKey), cachePolicy.useFreshCache(for: entry, now: .now) {
            return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
        }

        params["api_key"] = config.apiKey
        params["api_sig"] = signature(for: params)

        var bodyParams = params
        bodyParams["format"] = "json"

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formURLEncoded(bodyParams).data(using: .utf8)

        do {
            let (data, _) = try await urlSession.data(for: request)
            let payload = try parsePayload(data)

            if let code = parseErrorCode(payload["error"]) {
                let message = payload["message"] as? String ?? "Unknown error"
                throw mapAPIError(code: code, message: message)
            }

            if cachePolicy.shouldStore {
                let entry = EndpointCacheEntry(
                    data: data,
                    cachedAt: .now,
                    expiresAt: Date().addingTimeInterval(cachePolicy.ttlSeconds),
                    staleUntil: Date().addingTimeInterval(cachePolicy.staleFallbackSeconds)
                )
                setCachedEntry(entry, for: cacheKey)
            }
            return EndpointResponse(payload: payload, fromCache: false)
        } catch {
            if error is CancellationError {
                throw error
            }
            if cachePolicy.allowStaleFallback,
               let entry = cachedEntry(for: cacheKey),
               entry.staleUntil >= Date() {
                return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
            }
            if let error = error as? LastfmAPIError {
                throw error
            }
            if let error = error as? URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }
    }

    private func sendPublicRead(
        params: [String: String],
        cachePolicy: EndpointCachePolicy = .none
    ) async throws -> EndpointResponse {
        let cacheKey = "public|" + endpointCacheKey(params: params)
        if let entry = cachedEntry(for: cacheKey), cachePolicy.useFreshCache(for: entry, now: .now) {
            return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
        }

        var queryItems = params
        queryItems["api_key"] = config.apiKey
        queryItems["format"] = "json"

        var components = URLComponents(url: config.endpoint, resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems
            .sorted(by: { $0.key < $1.key })
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components?.url else {
            throw LastfmAPIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await urlSession.data(for: request)
            let payload = try parsePayload(data)

            if let code = parseErrorCode(payload["error"]) {
                let message = payload["message"] as? String ?? "Unknown error"
                throw mapAPIError(code: code, message: message)
            }

            if cachePolicy.shouldStore {
                let entry = EndpointCacheEntry(
                    data: data,
                    cachedAt: .now,
                    expiresAt: Date().addingTimeInterval(cachePolicy.ttlSeconds),
                    staleUntil: Date().addingTimeInterval(cachePolicy.staleFallbackSeconds)
                )
                setCachedEntry(entry, for: cacheKey)
            }
            return EndpointResponse(payload: payload, fromCache: false)
        } catch {
            if error is CancellationError {
                throw error
            }
            if cachePolicy.allowStaleFallback,
               let entry = cachedEntry(for: cacheKey),
               entry.staleUntil >= Date() {
                return try EndpointResponse(payload: parsePayload(entry.data), fromCache: true)
            }
            if let error = error as? LastfmAPIError {
                throw error
            }
            if let error = error as? URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                    throw LastfmAPIError.networkUnavailable
                default:
                    throw LastfmAPIError.transport
                }
            }
            throw LastfmAPIError.transport
        }
    }

    private func parsePayload(_ data: Data) throws -> [String: Any] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastfmAPIError.invalidResponse
        }
        return payload
    }

    private func mapAPIError(code: Int, message: String) -> LastfmAPIError {
        switch code {
        case 4:
            return .invalidCredentials
        case 9:
            return .invalidSession
        case 29:
            return .rateLimited(retryAfter: nil)
        default:
            return .api(code: code, message: message)
        }
    }

    private func parseErrorCode(_ value: Any?) -> Int? {
        if let code = value as? Int {
            return code
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let text = value as? String {
            return Int(text)
        }
        return nil
    }

    private func firstString(_ value: Any?) -> String? {
        if let text = value as? String, !text.isEmpty {
            return text
        }
        if let bool = value as? Bool {
            return bool ? "true" : "false"
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let dict = value as? [String: Any] {
            if let text = dict["#text"] as? String, !text.isEmpty {
                return text
            }
            if let text = dict["name"] as? String, !text.isEmpty {
                return text
            }
        }
        return nil
    }

    private func boolValue(_ value: Any?) -> Bool {
        guard let raw = firstString(value)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !raw.isEmpty else {
            return false
        }
        return raw == "1" || raw == "true" || raw == "yes" || raw == "on"
    }

    private func firstInt(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let string = firstString(value) {
            let cleaned = string
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: ".", with: "")
            if let int = Int(cleaned) {
                return int
            }
        }
        if let number = value as? NSNumber {
            return number.intValue
        }
        if let double = value as? Double {
            return Int(double)
        }
        if let float = value as? Float {
            return Int(float)
        }
        if let text = value as? String, let int = Int(text) {
            return int
        }
        return nil
    }

    private func firstInt(_ value: Any?, key: String) -> Int? {
        guard let dict = value as? [String: Any] else { return nil }
        return firstInt(dict[key])
    }

    private func imageURL(_ value: Any?) -> String? {
        if let text = firstString(value), !text.isEmpty, text != "true", text != "false" {
            return normalizedImageCandidate(text)
        }
        if let dict = value as? [String: Any] {
            if let text = firstString(dict["#text"]), !text.isEmpty {
                return normalizedImageCandidate(text)
            }
            let preferred = ["extralarge", "large", "medium", "small"]
            for size in preferred {
                if let candidate = normalizedImageCandidate(firstString(dict[size])), !candidate.isEmpty {
                    return candidate
                }
            }
        }
        guard let images = value as? [[String: Any]] else { return nil }
        let preferred = ["extralarge", "large", "medium", "small"]
        for size in preferred {
            if let match = images.first(where: { firstString($0["size"]) == size }),
               let text = normalizedImageCandidate(firstString(match["#text"])) {
                return text
            }
        }
        return images.compactMap { normalizedImageCandidate(firstString($0["#text"])) }.first
    }

    private func normalizedImageCandidate(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        // Last.fm's common generic placeholder avatar/artwork.
        if trimmed.contains("2a96cbd8b46e442fc41c2b86b821562f") {
            return nil
        }
        return trimmed
    }

    private func endpointCacheKey(params: [String: String]) -> String {
        params
            .sorted(by: { $0.key < $1.key })
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
    }

    private func signature(for params: [String: String]) -> String {
        LastfmSignature.make(params: params, sharedSecret: config.sharedSecret)
    }

    private func formURLEncoded(_ params: [String: String]) -> String {
        params
            .sorted(by: { $0.key < $1.key })
            .map { key, value in
                "\(escape(key))=\(escape(value))"
            }
            .joined(separator: "&")
    }

    private func escape(_ text: String) -> String {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    private func cachedEntry(for key: String) -> EndpointCacheEntry? {
        endpointCacheLock.lock()
        defer { endpointCacheLock.unlock() }
        return endpointCache[key]
    }

    private func setCachedEntry(_ entry: EndpointCacheEntry, for key: String) {
        endpointCacheLock.lock()
        endpointCache[key] = entry
        endpointCacheLock.unlock()
    }
}

final class LastfmAPIStub: LastfmAPI {
    let isConfigured = false
    private(set) var isAuthenticated = false
    private var session: LastfmSession?
    var sessionUsername: String? { session?.name }

    func authenticate(username: String, password: String) async throws -> LastfmSession {
        let session = LastfmSession(name: username, key: "stub-session")
        _ = password
        restoreSession(session)
        return session
    }

    func restoreSession(_ session: LastfmSession) {
        self.session = session
        isAuthenticated = true
    }

    func clearSession() {
        session = nil
        isAuthenticated = false
    }

    func validateSession() async throws -> LastfmSessionValidation {
        LastfmSessionValidation(
            isValid: isAuthenticated,
            checkedAt: .now,
            fromCache: false,
            capabilities: .unknown
        )
    }

    func nowPlaying(_ track: Track) async throws {
        _ = track
    }

    func scrobble(_ track: Track) async throws {
        _ = track
    }

    func love(track: String, artist: String) async throws {
        _ = track
        _ = artist
    }

    func unlove(track: String, artist: String) async throws {
        _ = track
        _ = artist
    }

    func fetchTrackDetails(artist: String, track: String) async throws -> LastfmTrackDetails {
        LastfmTrackDetails(
            name: track,
            artist: artist,
            album: "Unknown Album",
            imageURL: nil,
            listeners: 0,
            playcount: 0,
            userPlaycount: 0,
            url: nil,
            summary: "Track details are unavailable in stub mode.",
            tags: []
        )
    }

    func fetchArtistDetails(artist: String) async throws -> LastfmArtistDetails {
        LastfmArtistDetails(
            name: artist,
            imageURL: nil,
            listeners: 0,
            playcount: 0,
            userPlaycount: 0,
            url: nil,
            summary: "Artist details are unavailable in stub mode.",
            tags: [],
            similarArtists: []
        )
    }

    func fetchUserProfile() async throws -> LastfmUserProfile {
        LastfmUserProfile(
            name: "stub",
            realname: nil,
            playcount: 0,
            artistCount: 0,
            trackCount: 0,
            albumCount: 0,
            country: nil,
            url: nil,
            imageURL: nil,
            registeredAt: nil,
            accountType: nil
        )
    }

    func fetchRecentScrobbles(limit: Int) async throws -> [LastfmRecentScrobble] {
        let count = max(1, min(limit, 5))
        return (0..<count).map { index in
            LastfmRecentScrobble(
                id: "stub-\(index)",
                track: "Stub Track \(index + 1)",
                artist: "Stub Artist",
                album: "Stub Album",
                imageURL: nil,
                url: nil,
                loved: false,
                playedAt: Date().addingTimeInterval(TimeInterval(-index * 240)),
                nowPlaying: index == 0
            )
        }
    }

    func fetchFriendsListening(limit: Int) async throws -> [LastfmFriendListening] {
        let count = max(1, min(limit, 6))
        return (0..<count).map { index in
            LastfmFriendListening(
                id: "friend-\(index)",
                user: "friend\(index + 1)",
                realname: nil,
                country: "Unknown",
                isSubscriber: index % 3 == 0,
                accountType: index % 3 == 0 ? "subscriber" : (index % 5 == 0 ? "alum" : "user"),
                avatarURL: nil,
                track: index % 2 == 0 ? "Track \(index + 1)" : nil,
                artist: index % 2 == 0 ? "Artist \(index + 1)" : nil,
                imageURL: nil,
                playedAt: Date().addingTimeInterval(TimeInterval(-index * 420)),
                nowPlaying: index == 0
            )
        }
    }

    func fetchNeighbours(limit: Int) async throws -> [LastfmNeighbour] {
        let count = max(1, min(limit, 8))
        var result: [LastfmNeighbour] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let isSubscriber = index % 3 == 0
            let accountType: String
            if index % 5 == 0 {
                accountType = "alum"
            } else if isSubscriber {
                accountType = "subscriber"
            } else {
                accountType = "user"
            }
            let match = max(0.05, 0.95 - (Double(index) * 0.08))
            result.append(
                LastfmNeighbour(
                    id: "neighbour-\(index)",
                    user: "neighbour\(index + 1)",
                    realname: nil,
                    country: index % 2 == 0 ? "Unknown" : "Spain",
                    isSubscriber: isSubscriber,
                    accountType: accountType,
                    avatarURL: nil,
                    profileURL: "https://www.last.fm/user/neighbour\(index + 1)",
                    matchScore: match
                )
            )
        }
        return result
    }

    func fetchFriendUsernames(user: String, limit: Int) async throws -> [String] {
        let seed = [
            "bbc6music", "degraph", "blessedheart", "himitsuUK", "koralute",
            "krowder", "lobnasz", "dissserj", "fromaj", "mattazathoth"
        ]
        let count = max(1, min(limit, seed.count))
        if user.lowercased() == (session?.name.lowercased() ?? "") {
            return Array(seed.prefix(count))
        }
        return Array(seed.shuffled().prefix(count))
    }

    func fetchTopArtists(period: LastfmTopArtistPeriod, limit: Int) async throws -> [LastfmTopArtist] {
        let count = max(1, min(limit, 8))
        return (0..<count).map { index in
            LastfmTopArtist(
                id: "\(period.rawValue)-stub-\(index)",
                name: "\(periodLabel(period)) Artist \(index + 1)",
                playcount: 100 - index * 7,
                imageURL: nil,
                url: nil
            )
        }
    }

    func fetchGlobalTopArtists(limit: Int) async throws -> [String] {
        let seed = [
            "Taylor Swift", "Drake", "The Weeknd", "Bad Bunny", "Billie Eilish",
            "Coldplay", "Kendrick Lamar", "Ariana Grande", "Radiohead", "Pink Floyd"
        ]
        return Array(seed.prefix(max(1, min(limit, seed.count))))
    }

    private func periodLabel(_ period: LastfmTopArtistPeriod) -> String {
        switch period {
        case .week:
            return "Weekly"
        case .month:
            return "Monthly"
        case .year:
            return "Yearly"
        case .overall:
            return "Overall"
        }
    }

    func fetchLovedTracksCount() async throws -> Int? {
        0
    }
}

private struct EndpointResponse {
    let payload: [String: Any]
    let fromCache: Bool
}

private struct EndpointCacheEntry {
    let data: Data
    let cachedAt: Date
    let expiresAt: Date
    let staleUntil: Date
}

private enum EndpointCachePolicy {
    case none
    case ttl(seconds: TimeInterval, staleFallbackSeconds: TimeInterval)

    var shouldStore: Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return true
        }
    }

    var allowStaleFallback: Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return true
        }
    }

    var ttlSeconds: TimeInterval {
        switch self {
        case .none:
            return 0
        case let .ttl(seconds, _):
            return seconds
        }
    }

    var staleFallbackSeconds: TimeInterval {
        switch self {
        case .none:
            return 0
        case let .ttl(_, staleFallbackSeconds):
            return staleFallbackSeconds
        }
    }

    func useFreshCache(for entry: EndpointCacheEntry, now: Date) -> Bool {
        switch self {
        case .none:
            return false
        case .ttl:
            return entry.expiresAt >= now
        }
    }
}
