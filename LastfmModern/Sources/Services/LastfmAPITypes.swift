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
    func fetchSimilarTracks(artist: String, track: String, limit: Int) async throws -> [LastfmSimilarTrack]
    func fetchSimilarAlbums(artist: String, album: String, limit: Int) async throws -> [LastfmSimilarAlbum]
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

struct LastfmSimilarTrack: Equatable, Identifiable {
    let id: String
    let name: String
    let artist: String
    let imageURL: String?
    let url: String?
}

struct LastfmSimilarAlbum: Equatable, Identifiable {
    let id: String
    let name: String
    let artist: String
    let imageURL: String?
    let url: String?
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

struct ArtistImageSupplement {
    let imageURL: String?
    let similarArtistImages: [String: String]
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
