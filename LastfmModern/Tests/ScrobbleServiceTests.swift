import XCTest
@testable import LastfmModern

final class ScrobbleServiceTests: XCTestCase {
    @MainActor
    func testManualQueueAvoidsDuplicates() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        service.queueCurrentTrack()
        service.queueCurrentTrack()

        XCTAssertEqual(service.queuedScrobbles.count, 1)
    }

    @MainActor
    func testShortTrackIsRejectedByRules() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 10)))
        await Task.yield()
        service.queueCurrentTrack()

        XCTAssertTrue(service.queuedScrobbles.isEmpty)
    }

    @MainActor
    func testSubmitQueuedRemovesOnSuccess() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        service.queueCurrentTrack()
        await service.submitQueued()

        XCTAssertTrue(service.queuedScrobbles.isEmpty)
        XCTAssertEqual(api.scrobbledTracks.count, 1)
    }

    @MainActor
    func testNowPlayingWaitsForResumeAfterPause() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let sleepLatch = SleepLatch()
        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore(),
            retryJitter: { 1.0 },
            sleepFunction: { _ in await sleepLatch.wait() }
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        monitor.emit(.paused)
        await Task.yield()

        await sleepLatch.release(1)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(api.nowPlayingTracks.count, 0)

        monitor.emit(.resumed)
        await Task.yield()
        await sleepLatch.release(1)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(api.nowPlayingTracks.count, 1)
        withExtendedLifetime(service) {}
    }

    @MainActor
    func testFailedSubmitSchedulesRetryAndBackoff() async {
        let api = MockAPI(scrobbleFailuresRemaining: 1)
        let monitor = TestMonitor()
        let sleepLatch = SleepLatch()
        let queueStore = InMemoryQueueStore(
            initialTracks: [makeTrack(duration: 180)]
        )

        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: queueStore,
            retryJitter: { 1.0 },
            sleepFunction: { _ in await sleepLatch.wait() }
        )

        XCTAssertTrue(service.isRetryScheduled)
        XCTAssertEqual(service.retryDelaySeconds, 4)

        await service.submitQueued()

        XCTAssertEqual(api.scrobbleAttempts, 1)
        XCTAssertEqual(service.queuedScrobbles.count, 1)
        XCTAssertTrue(service.isRetryScheduled)
        XCTAssertEqual(service.retryDelaySeconds, 8)
        XCTAssertNotNil(service.lastAPIError)
        XCTAssertNotNil(service.lastRecoveryHint)
    }

    @MainActor
    func testStartupValidationInvalidatesStoredSession() async {
        let api = MockAPI()
        api.isAuthenticated = true
        api.sessionValidationResult = .success(
            LastfmSessionValidation(
                isValid: false,
                checkedAt: .now,
                fromCache: false,
                capabilities: .unknown
            )
        )
        let monitor = TestMonitor()
        let sessionStore = InMemorySessionStore()
        sessionStore.save(LastfmSession(name: "tester", key: "session"))
        let service = ScrobbleService(
            api: api,
            monitor: monitor,
            sessionStore: sessionStore,
            queueStore: InMemoryQueueStore()
        )

        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.sessionStatus, "Session invalid")
        XCTAssertEqual(sessionStore.load(), nil)
        XCTAssertGreaterThanOrEqual(api.validateSessionCalls, 1)
        withExtendedLifetime(service) {}
    }

    private func makeTrack(duration: TimeInterval) -> Track {
        Track(
            title: "Track",
            artist: "Artist",
            album: "Album",
            duration: duration,
            startedAt: .now,
            sourceApp: "Test"
        )
    }
}

private final class MockAPI: LastfmAPI {
    var nowPlayingTracks: [Track] = []
    var isConfigured: Bool = true
    var isAuthenticated: Bool = true
    var scrobbledTracks: [Track] = []
    var scrobbleFailuresRemaining: Int
    var scrobbleAttempts = 0
    var validateSessionCalls = 0
    var sessionValidationResult: Result<LastfmSessionValidation, Error> = .success(
        LastfmSessionValidation(
            isValid: true,
            checkedAt: .now,
            fromCache: false,
            capabilities: .unknown
        )
    )

    init(scrobbleFailuresRemaining: Int = 0) {
        self.scrobbleFailuresRemaining = scrobbleFailuresRemaining
    }

    func authenticate(username: String, password: String) async throws -> LastfmSession {
        _ = username
        _ = password
        return LastfmSession(name: "tester", key: "session")
    }

    func restoreSession(_ session: LastfmSession) {
        _ = session
        isAuthenticated = true
    }

    func clearSession() {
        isAuthenticated = false
    }

    func validateSession() async throws -> LastfmSessionValidation {
        validateSessionCalls += 1
        return try sessionValidationResult.get()
    }

    func nowPlaying(_ track: Track) async throws {
        nowPlayingTracks.append(track)
    }

    func scrobble(_ track: Track) async throws {
        scrobbleAttempts += 1
        if scrobbleFailuresRemaining > 0 {
            scrobbleFailuresRemaining -= 1
            throw URLError(.notConnectedToInternet)
        }
        scrobbledTracks.append(track)
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
            album: "Album",
            imageURL: nil,
            listeners: 1,
            playcount: 1,
            userPlaycount: 1,
            url: nil,
            summary: nil,
            tags: []
        )
    }

    func fetchArtistDetails(artist: String) async throws -> LastfmArtistDetails {
        LastfmArtistDetails(
            name: artist,
            imageURL: nil,
            listeners: 1,
            playcount: 1,
            userPlaycount: 1,
            url: nil,
            summary: nil,
            tags: [],
            similarArtists: []
        )
    }

    func fetchUserProfile() async throws -> LastfmUserProfile {
        LastfmUserProfile(
            name: "tester",
            realname: nil,
            playcount: 1,
            artistCount: 1,
            trackCount: 1,
            albumCount: 1,
            country: nil,
            url: nil,
            imageURL: nil,
            registeredAt: nil
        )
    }

    func fetchRecentScrobbles(limit: Int) async throws -> [LastfmRecentScrobble] {
        [LastfmRecentScrobble(
            id: "test",
            track: "Track",
            artist: "Artist",
            album: "Album",
            imageURL: nil,
            url: nil,
            loved: false,
            playedAt: .now,
            nowPlaying: false
        )]
    }

    func fetchFriendsListening(limit: Int) async throws -> [LastfmFriendListening] {
        [LastfmFriendListening(
            id: "friend",
            user: "friend",
            realname: nil,
            country: nil,
            isSubscriber: false,
            avatarURL: nil,
            track: "Track",
            artist: "Artist",
            imageURL: nil,
            playedAt: .now,
            nowPlaying: true
        )]
    }

    func fetchTopArtists(period: LastfmTopArtistPeriod, limit: Int) async throws -> [LastfmTopArtist] {
        _ = period
        _ = limit
        return [LastfmTopArtist(id: "artist", name: "Artist", playcount: 10, imageURL: nil, url: nil)]
    }

    func fetchGlobalTopArtists(limit: Int) async throws -> [String] {
        _ = limit
        return ["Artist", "Another Artist"]
    }

    func fetchLovedTracksCount() async throws -> Int? {
        0
    }
}

private final class TestMonitor: PlayerMonitor {
    var onEvent: ((PlayerEvent) -> Void)?
    var statusDescription: String = "Test monitor"

    func start() {}
    func stop() {}

    func emit(_ event: PlayerEvent) {
        onEvent?(event)
    }
}

private final class InMemorySessionStore: LastfmSessionStoring {
    private var session: LastfmSession?

    func save(_ session: LastfmSession) {
        self.session = session
    }

    func load() -> LastfmSession? {
        session
    }

    func clear() {
        session = nil
    }
}

private final class InMemoryQueueStore: ScrobbleQueueStoring {
    let queueFileURL = URL(fileURLWithPath: "/tmp/lastfmmodern-test-queue.json")
    private var tracks: [Track] = []

    init(initialTracks: [Track] = []) {
        tracks = initialTracks
    }

    func load() -> [Track] {
        tracks
    }

    func save(_ tracks: [Track]) {
        self.tracks = tracks
    }
}

private actor SleepLatch {
    private var permits = 0

    func wait() async {
        while true {
            if Task.isCancelled {
                return
            }
            if permits > 0 {
                permits -= 1
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func release(_ count: Int) {
        permits += count
    }
}
