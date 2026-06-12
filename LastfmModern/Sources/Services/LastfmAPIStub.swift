import Foundation

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

    func fetchSimilarTracks(artist: String, track: String, limit: Int) async throws -> [LastfmSimilarTrack] {
        _ = artist
        _ = track
        _ = limit
        return []
    }

    func fetchSimilarAlbums(artist: String, album: String, limit: Int) async throws -> [LastfmSimilarAlbum] {
        _ = artist
        _ = album
        _ = limit
        return []
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
            let friendId = "friend-\(index)"
            let username = "friend\(index + 1)"
            let isSubscriber = index % 3 == 0
            let type: String = index % 3 == 0 ? "subscriber" : (index % 5 == 0 ? "alum" : "user")
            let hasTrack = index % 2 == 0
            let trackName: String? = hasTrack ? "Track \(index + 1)" : nil
            let artistName: String? = hasTrack ? "Artist \(index + 1)" : nil
            let date = Date().addingTimeInterval(TimeInterval(-index * 420))
            let isNowPlaying = index == 0

            return LastfmFriendListening(
                id: friendId,
                user: username,
                realname: nil,
                country: "Unknown",
                isSubscriber: isSubscriber,
                accountType: type,
                avatarURL: nil,
                track: trackName,
                artist: artistName,
                imageURL: nil,
                playedAt: date,
                nowPlaying: isNowPlaying
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
