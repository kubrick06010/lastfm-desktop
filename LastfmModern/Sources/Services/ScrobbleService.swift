import Foundation

struct SocialGraphNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let degree: Int
    let isTarget: Bool
    let isSource: Bool
}

struct SocialGraphEdge: Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
}

struct SocialGraphSnapshot: Equatable {
    let sourceUser: String
    let nodes: [SocialGraphNode]
    let edges: [SocialGraphEdge]
    let generatedAt: Date
}

@MainActor
final class ScrobbleService: ObservableObject {
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queuedScrobbles: [Track] = []
    @Published private(set) var scrobblingEnabled = true
    @Published private(set) var isAuthenticated = false
    @Published private(set) var apiConfigured = false
    @Published private(set) var backendName = "Stub"
    @Published private(set) var authError: String?
    @Published private(set) var lastAPIError: String?
    @Published private(set) var monitorStatus = ""
    @Published private(set) var playbackState = "Stopped"
    @Published private(set) var lastSubmittedAt: Date?
    @Published private(set) var queueFilePath = ""
    @Published private(set) var sessionStatus = "Not authenticated"
    @Published private(set) var sessionUsername: String?
    @Published private(set) var capabilitiesStatus = "Unknown"
    @Published private(set) var validationSource = "Live"
    @Published private(set) var lastRecoveryHint: String?
    @Published private(set) var elapsedForCurrentTrack: TimeInterval = 0
    @Published private(set) var scrobbleThreshold: TimeInterval = 0
    @Published private(set) var scrobbleProgress: Double = 0
    @Published private(set) var retryDelaySeconds = 2
    @Published private(set) var isRetryScheduled = false
    @Published private(set) var nextRetryAt: Date?
    @Published private(set) var nowPlayingDelaySeconds = 10
    @Published private(set) var queueSubmitAttempts = 0
    @Published private(set) var queueSubmitFailures = 0
    @Published private(set) var playerEventCount = 0
    @Published private(set) var currentTrackDetails: LastfmTrackDetails?
    @Published private(set) var currentArtistDetails: LastfmArtistDetails?
    @Published private(set) var inspectedTrackDetails: LastfmTrackDetails?
    @Published private(set) var inspectedArtistDetails: LastfmArtistDetails?
    @Published private(set) var inspectStatus = "Select a scrobble to inspect"
    @Published private(set) var profile: LastfmUserProfile?
    @Published private(set) var latestScrobbles: [LastfmRecentScrobble] = []
    @Published private(set) var friendsListening: [LastfmFriendListening] = []
    @Published private(set) var neighbours: [LastfmNeighbour] = []
    @Published private(set) var separationByUser: [String: Int] = [:]
    @Published private(set) var separationStatus = "Not calculated"
    @Published private(set) var socialGraph: SocialGraphSnapshot?
    @Published private(set) var weeklyTopArtists: [LastfmTopArtist] = []
    @Published private(set) var monthlyTopArtists: [LastfmTopArtist] = []
    @Published private(set) var yearlyTopArtists: [LastfmTopArtist] = []
    @Published private(set) var overallTopArtists: [LastfmTopArtist] = []
    @Published private(set) var globalTopArtistNames: [String] = []
    @Published private(set) var lovedTracksCount: Int?
    @Published private(set) var tracksPerDayAverage: Int?
    @Published private(set) var isSubscriber = false
    @Published private(set) var exploreStatus = "Waiting for track"
    @Published private(set) var profileStatus = "Not loaded"
    @Published private(set) var scrobblesStatus = "Not loaded"
    @Published private(set) var friendsStatus = "Not loaded"
    @Published private(set) var neighboursStatus = "Not loaded"

    private var api: LastfmAPI
    private let monitor: PlayerMonitor
    private let sessionStore: LastfmSessionStoring
    private let queueStore: ScrobbleQueueStoring

    private var currentTrackStart: Date?
    private var accumulatedPlayTime: TimeInterval = 0
    private var thresholdTask: Task<Void, Never>?
    private var nowPlayingTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var exploreTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var friendsRefreshTask: Task<Void, Never>?
    private var separationTask: Task<Void, Never>?
    private var hasQueuedCurrentTrack = false
    private var hasSentNowPlayingForCurrentTrack = false
    private var recentScrobbles: [String: Date] = [:]
    private var friendGraphCache: [String: [String]] = [:]
    private let inferredNowPlayingWindow: TimeInterval = 30 * 60
    private let quickSeparationDepth = 6
    private let detailedSeparationDepth = 24
    private let retryJitter: () -> Double
    private let sleepFunction: @Sendable (UInt64) async -> Void

    init(
        api: LastfmAPI? = nil,
        monitor: PlayerMonitor = makeDefaultPlayerMonitor(),
        sessionStore: LastfmSessionStoring = LastfmSessionStore(),
        queueStore: ScrobbleQueueStoring = ScrobbleQueueStore(),
        retryJitter: @escaping () -> Double = { Double.random(in: 0.85...1.15) },
        sleepFunction: @escaping @Sendable (UInt64) async -> Void = { nanos in
            try? await Task.sleep(nanoseconds: nanos)
        }
    ) {
        if let api {
            self.api = api
        } else if let config = LastfmAPIConfig.fromEnvironment() {
            self.api = LastfmAPIClient(config: config)
        } else {
            self.api = LastfmAPIStub()
        }

        self.monitor = monitor
        self.sessionStore = sessionStore
        self.queueStore = queueStore
        self.retryJitter = retryJitter
        self.sleepFunction = sleepFunction
        self.queuedScrobbles = queueStore.load()
        self.apiConfigured = self.api.isConfigured
        self.backendName = self.api.isConfigured ? "Live Last.fm API" : "Stub (missing LASTFM_API_KEY and LASTFM_SHARED_SECRET)"
        self.monitorStatus = monitor.statusDescription
        self.queueFilePath = queueStore.queueFileURL.path

        if let session = sessionStore.load() {
            self.api.restoreSession(session)
        }
        self.isAuthenticated = self.api.isAuthenticated
        self.sessionUsername = self.api.sessionUsername
        self.sessionStatus = self.isAuthenticated ? "Authenticated (not yet validated)" : "Not authenticated"

        self.monitor.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handlePlayerEvent(event)
            }
        }
        self.monitor.start()

        if self.isAuthenticated {
            Task {
                await validateSessionOnStartup()
                await refreshProfileData()
                await refreshScrobblesData()
                await refreshFriendsData()
                await refreshNeighboursData()
                startFriendsAutoRefresh()
            }
        }

        if !self.queuedScrobbles.isEmpty {
            scheduleRetryIfNeeded()
        }
    }

    deinit {
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        retryTask?.cancel()
        progressTask?.cancel()
        exploreTask?.cancel()
        profileTask?.cancel()
        friendsRefreshTask?.cancel()
        separationTask?.cancel()
        monitor.stop()
    }

    func toggleScrobbling() {
        scrobblingEnabled.toggle()
        if scrobblingEnabled {
            scheduleRetryIfNeeded()
        } else {
            cancelRetrySchedule()
        }
    }

    func signIn(username: String, password: String) async {
        authError = nil
        guard !username.isEmpty, !password.isEmpty else {
            authError = "Username and password are required."
            return
        }

        do {
            let session = try await api.authenticate(username: username, password: password)
            sessionStore.save(session)
            isAuthenticated = api.isAuthenticated
            sessionUsername = session.name
            friendGraphCache = [:]
            separationByUser = [:]
            separationStatus = "Not calculated"
            socialGraph = nil
            scheduleRetryIfNeeded()
            await validateSessionOnStartup()
            await refreshProfileData()
            await refreshScrobblesData()
            await refreshFriendsData()
            await refreshNeighboursData()
            startFriendsAutoRefresh()
        } catch {
            handle(error: error)
            authError = lastAPIError
        }
    }

    func signOut() {
        api.clearSession()
        sessionStore.clear()
        isAuthenticated = false
        sessionUsername = nil
        authError = nil
        sessionStatus = "Not authenticated"
        capabilitiesStatus = "Unknown"
        validationSource = "Live"
        profile = nil
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectStatus = "Select a scrobble to inspect"
        latestScrobbles = []
        weeklyTopArtists = []
        monthlyTopArtists = []
        yearlyTopArtists = []
        overallTopArtists = []
        globalTopArtistNames = []
        lovedTracksCount = nil
        tracksPerDayAverage = nil
        profileStatus = "Not loaded"
        scrobblesStatus = "Not loaded"
        isSubscriber = false
        friendsListening = []
        friendsStatus = "Not loaded"
        neighbours = []
        neighboursStatus = "Not loaded"
        separationByUser = [:]
        separationStatus = "Not calculated"
        socialGraph = nil
        separationTask?.cancel()
        separationTask = nil
        friendGraphCache = [:]
        friendsRefreshTask?.cancel()
        friendsRefreshTask = nil
        cancelRetrySchedule()
    }

    func refreshExplore() async {
        guard let track = currentTrack else {
            exploreStatus = "Waiting for track"
            currentTrackDetails = nil
            currentArtistDetails = nil
            return
        }
        await refreshExploreData(for: track)
    }

    func refreshProfile() async {
        await refreshProfileData()
    }

    func refreshScrobbles() async {
        await refreshScrobblesData()
    }

    func refreshFriends() async {
        await refreshFriendsData()
    }

    func refreshNeighbours() async {
        await refreshNeighboursData()
    }

    func prepareSocialGraph(for targetUser: String) async {
        let target = targetUser.trimmingCharacters(in: .whitespacesAndNewlines)
        separationTask?.cancel()
        socialGraph = nil
        guard !target.isEmpty else {
            separationStatus = "No target user selected"
            socialGraph = nil
            return
        }
        guard isAuthenticated else {
            separationStatus = "Sign in to calculate separation"
            socialGraph = nil
            return
        }
        guard let source = api.sessionUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            separationStatus = "No source user available"
            socialGraph = nil
            return
        }

        let targetLower = target.lowercased()
        let sourceLower = source.lowercased()
        if targetLower == sourceLower {
            separationByUser[targetLower] = 0
            separationStatus = "You are 0° away from \(target)"
            socialGraph = SocialGraphSnapshot(
                sourceUser: source,
                nodes: [
                    SocialGraphNode(
                        id: sourceLower,
                        displayName: source,
                        degree: 0,
                        isTarget: true,
                        isSource: true
                    )
                ],
                edges: [],
                generatedAt: Date()
            )
            return
        }

        separationStatus = "Calculating path to \(target)..."
        let results = await bfsDegrees(
            from: source,
            targets: [target],
            maxDepth: detailedSeparationDepth,
            includeContext: false
        )
        guard !Task.isCancelled else { return }
        socialGraph = results.graph

        if let degree = results.degrees[targetLower] {
            separationByUser[targetLower] = degree
            separationStatus = "Found a \(degree)° path to \(target)"
        } else {
            separationByUser[targetLower] = nil
            separationStatus = "No path found within \(detailedSeparationDepth)° for \(target)"
        }
    }

    func separationDegree(for user: String) -> Int? {
        separationByUser[user.lowercased()]
    }

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

        var loadedAnything = false
        var degraded = false
        let isArtistOnlyInspection =
            scrobble.id.hasPrefix("deep-") &&
            scrobble.track.trimmingCharacters(in: .whitespacesAndNewlines)
                .caseInsensitiveCompare(scrobble.artist.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame

        if !isArtistOnlyInspection {
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

    private func fetchWithRetry<T>(_ work: @escaping () async throws -> T) async throws -> T {
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

    private func shouldRetryInspection(_ error: Error) -> Bool {
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

    private func updateLovedState(for id: String, loved: Bool) {
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

    func submitQueued() async {
        guard scrobblingEnabled, isAuthenticated else {
            cancelRetrySchedule()
            return
        }
        cancelRetrySchedule()
        queueSubmitAttempts += 1
        lastAPIError = nil
        var pending = queuedScrobbles
        var shouldRetry = false
        var shouldStop = false

        while let track = pending.first, !shouldStop {
            do {
                try await api.scrobble(track)
                recentScrobbles[track.fingerprint] = .now
                pending.removeFirst()
            } catch {
                queueSubmitFailures += 1
                handle(error: error)

                if isRetryableSubmissionError(error) {
                    shouldRetry = true
                    break
                }

                // Drop permanently-failing scrobbles so the queue can keep moving.
                pending.removeFirst()

                if let apiError = error as? LastfmAPIError {
                    switch apiError {
                    case .missingSession, .invalidSession, .invalidCredentials:
                        signOut()
                        shouldRetry = false
                        shouldStop = true
                    default:
                        break
                    }
                }
            }
        }

        queuedScrobbles = pending
        if queuedScrobbles.isEmpty {
            lastSubmittedAt = .now
            resetRetryBackoff()
        } else if shouldRetry {
            scheduleRetryIfNeeded()
        }
        persistQueue()
    }

    func queueCurrentTrack() {
        guard let currentTrack, scrobblingEnabled else { return }
        queueIfEligible(currentTrack)
    }

    func retryQueueNow() async {
        guard scrobblingEnabled, isAuthenticated else { return }
        resetRetryBackoff()
        await submitQueued()
    }

    func clearQueue() {
        queuedScrobbles.removeAll()
        resetRetryBackoff()
        persistQueue()
    }

    private func handlePlayerEvent(_ event: PlayerEvent) {
        playerEventCount += 1
        switch event {
        case let .trackStarted(track):
            handleTrackStarted(track)
        case .paused:
            handlePaused()
        case .resumed:
            handleResumed()
        case .stopped:
            handleStopped()
        }
    }

    private func handleTrackStarted(_ track: Track) {
        finalizeCurrentTrackIfNeeded()

        currentTrack = track
        currentTrackStart = .now
        accumulatedPlayTime = 0
        hasQueuedCurrentTrack = false
        hasSentNowPlayingForCurrentTrack = false
        elapsedForCurrentTrack = 0
        scrobbleThreshold = threshold(for: track)
        scrobbleProgress = 0
        playbackState = "Playing"

        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        scheduleThresholdCheck()
        scheduleNowPlayingIfNeeded()
        startProgressUpdates()

        exploreTask?.cancel()
        exploreTask = Task { @MainActor in
            await refreshExploreData(for: track)
        }
    }

    private func handlePaused() {
        guard playbackState == "Playing" else { return }
        updateElapsedPlayTime()
        playbackState = "Paused"
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
    }

    private func handleResumed() {
        guard playbackState == "Paused", currentTrack != nil else { return }
        playbackState = "Playing"
        currentTrackStart = .now
        scheduleThresholdCheck()
        scheduleNowPlayingIfNeeded()
        startProgressUpdates()
    }

    private func handleStopped() {
        finalizeCurrentTrackIfNeeded()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
        resetPlaybackState()
    }

    private func finalizeCurrentTrackIfNeeded() {
        updateElapsedPlayTime()
        guard let track = currentTrack else { return }

        if elapsedForCurrentTrack >= threshold(for: track) {
            queueIfEligible(track)
        }
    }

    private func updateElapsedPlayTime() {
        guard let start = currentTrackStart else { return }
        accumulatedPlayTime += max(0, Date().timeIntervalSince(start))
        elapsedForCurrentTrack = accumulatedPlayTime
        scrobbleProgress = progressValue(elapsed: elapsedForCurrentTrack, threshold: scrobbleThreshold)
        currentTrackStart = nil
    }

    private func scheduleThresholdCheck() {
        guard let track = currentTrack else { return }
        let needed = max(0, threshold(for: track) - accumulatedPlayTime)
        guard needed > 0 else {
            queueIfEligible(track)
            return
        }

        thresholdTask?.cancel()
        thresholdTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(needed * 1_000_000_000))
            await MainActor.run {
                guard self.playbackState == "Playing", self.currentTrack?.id == track.id else { return }
                self.updateElapsedPlayTime()
                self.queueIfEligible(track)
            }
        }
    }

    private func queueIfEligible(_ track: Track) {
        guard scrobblingEnabled else { return }
        guard isTrackScrobblable(track) else { return }
        guard !hasQueuedCurrentTrack else { return }

        pruneRecentScrobbles()
        let fingerprint = track.fingerprint
        guard recentScrobbles[fingerprint] == nil else { return }
        guard !queuedScrobbles.contains(where: { $0.fingerprint == fingerprint }) else { return }

        queuedScrobbles.append(track)
        hasQueuedCurrentTrack = true
        persistQueue()
        scheduleRetryIfNeeded()
    }

    private func isTrackScrobblable(_ track: Track) -> Bool {
        guard !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard track.duration >= 30 else { return false }
        return true
    }

    private func threshold(for track: Track) -> TimeInterval {
        min(240, max(30, track.duration * 0.5))
    }

    private func persistQueue() {
        queueStore.save(queuedScrobbles)
    }

    private func isRetryableSubmissionError(_ error: Error) -> Bool {
        guard let apiError = error as? LastfmAPIError else {
            return true
        }
        switch apiError {
        case .networkUnavailable, .transport, .rateLimited:
            return true
        case .missingSession, .invalidCredentials, .invalidSession:
            return false
        case .invalidResponse:
            return true
        case .api:
            return false
        }
    }

    private func scheduleNowPlayingIfNeeded() {
        guard scrobblingEnabled, isAuthenticated else { return }
        guard playbackState == "Playing" else { return }
        guard let track = currentTrack else { return }
        guard !hasSentNowPlayingForCurrentTrack else { return }

        nowPlayingTask?.cancel()
        let delay = UInt64(nowPlayingDelaySeconds) * 1_000_000_000
        nowPlayingTask = Task {
            await sleepFunction(delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard self.playbackState == "Playing" else { return }
                guard self.currentTrack?.id == track.id else { return }
                guard !self.hasSentNowPlayingForCurrentTrack else { return }

                Task {
                    do {
                        try await self.api.nowPlaying(track)
                        await MainActor.run {
                            self.hasSentNowPlayingForCurrentTrack = true
                        }
                    } catch {
                        await MainActor.run {
                            self.handle(error: error)
                        }
                    }
                }
            }
        }
    }

    private func scheduleRetryIfNeeded() {
        guard scrobblingEnabled, isAuthenticated else { return }
        guard !queuedScrobbles.isEmpty else { return }
        guard !isRetryScheduled else { return }

        let jittered = max(1, Int(Double(retryDelaySeconds) * retryJitter()))
        let fireDate = Date().addingTimeInterval(TimeInterval(jittered))
        isRetryScheduled = true
        nextRetryAt = fireDate

        retryTask?.cancel()
        retryTask = Task {
            await sleepFunction(UInt64(jittered) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.isRetryScheduled = false
                self.nextRetryAt = nil
                // Clear task reference before submit; submitQueued() may reset retry state.
                self.retryTask = nil
            }
            guard !Task.isCancelled else { return }
            await submitQueued()
        }

        retryDelaySeconds = min(retryDelaySeconds * 2, 7200)
    }

    private func cancelRetrySchedule() {
        retryTask?.cancel()
        retryTask = nil
        isRetryScheduled = false
        nextRetryAt = nil
    }

    private func resetRetryBackoff() {
        cancelRetrySchedule()
        retryDelaySeconds = 2
    }

    private func pruneRecentScrobbles() {
        let cutoff = Date().addingTimeInterval(-60 * 60)
        recentScrobbles = recentScrobbles.filter { $0.value >= cutoff }
    }

    private func resetPlaybackState() {
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        thresholdTask = nil
        nowPlayingTask = nil
        currentTrack = nil
        currentTrackStart = nil
        accumulatedPlayTime = 0
        elapsedForCurrentTrack = 0
        scrobbleThreshold = 0
        scrobbleProgress = 0
        playbackState = "Stopped"
        hasQueuedCurrentTrack = false
        hasSentNowPlayingForCurrentTrack = false
    }

    private func refreshExploreData(for track: Track) async {
        guard isAuthenticated else {
            exploreStatus = "Sign in to load track and artist details"
            currentTrackDetails = nil
            currentArtistDetails = nil
            return
        }
        exploreStatus = "Loading track and artist details..."
        lastAPIError = nil
        lastRecoveryHint = nil

        var loadedAnything = false

        do {
            currentTrackDetails = try await api.fetchTrackDetails(artist: track.artist, track: track.title)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            currentTrackDetails = nil
            handle(error: error)
        }

        do {
            currentArtistDetails = try await api.fetchArtistDetails(artist: track.artist)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            currentArtistDetails = nil
            handle(error: error)
        }

        exploreStatus = loadedAnything ? "Loaded" : "Failed to load details"
    }

    private func refreshProfileData() async {
        guard isAuthenticated else {
            profileStatus = "Sign in to load profile"
            profile = nil
            weeklyTopArtists = []
            monthlyTopArtists = []
            yearlyTopArtists = []
            overallTopArtists = []
            globalTopArtistNames = []
            lovedTracksCount = nil
            tracksPerDayAverage = nil
            return
        }
        profileStatus = "Loading profile..."
        lastAPIError = nil
        lastRecoveryHint = nil

        profileTask?.cancel()
        profileTask = Task { @MainActor in
            do {
                let profile = try await api.fetchUserProfile()
                async let weekly = api.fetchTopArtists(period: .week, limit: 30)
                async let month = api.fetchTopArtists(period: .month, limit: 40)
                async let year = api.fetchTopArtists(period: .year, limit: 40)
                async let overall = api.fetchTopArtists(period: .overall, limit: 40)
                async let lovedCount = api.fetchLovedTracksCount()
                async let global = api.fetchGlobalTopArtists(limit: 1000)
                self.profile = profile
                let weeklyBase = try await weekly
                let monthlyBase = try await month
                let yearlyBase = try await year
                let overallBase = try await overall
                self.weeklyTopArtists = await self.hydrateTopArtistImages(weeklyBase)
                self.monthlyTopArtists = await self.hydrateTopArtistImages(monthlyBase)
                self.yearlyTopArtists = await self.hydrateTopArtistImages(yearlyBase)
                self.overallTopArtists = await self.hydrateTopArtistImages(overallBase)
                self.lovedTracksCount = try await lovedCount
                self.globalTopArtistNames = (try? await global) ?? []
                self.tracksPerDayAverage = self.computeTracksPerDayAverage(profile)
                self.profileStatus = "Loaded"
            } catch is CancellationError {
                return
            } catch {
                self.handle(error: error)
                self.profileStatus = "Failed to load profile"
            }
        }
    }

    private func refreshScrobblesData() async {
        guard isAuthenticated else {
            scrobblesStatus = "Sign in to load scrobbles"
            latestScrobbles = []
            return
        }
        scrobblesStatus = "Loading scrobbles..."
        lastAPIError = nil
        lastRecoveryHint = nil

        do {
            latestScrobbles = try await api.fetchRecentScrobbles(limit: 1000)
            scrobblesStatus = "Loaded"
        } catch is CancellationError {
            return
        } catch {
            handle(error: error)
            scrobblesStatus = "Failed to load scrobbles"
        }
    }

    private func refreshFriendsData() async {
        guard isAuthenticated else {
            friendsStatus = "Sign in to load friends"
            friendsListening = []
            return
        }
        friendsStatus = "Loading friends..."
        lastAPIError = nil
        lastRecoveryHint = nil

        do {
            friendsListening = try await api.fetchFriendsListening(limit: 1000).map { friend in
                let inferredNowPlaying = inferredNowPlayingState(for: friend)
                guard inferredNowPlaying != friend.nowPlaying else { return friend }
                return LastfmFriendListening(
                    id: friend.id,
                    user: friend.user,
                    realname: friend.realname,
                    country: friend.country,
                    isSubscriber: friend.isSubscriber,
                    accountType: friend.accountType,
                    avatarURL: friend.avatarURL,
                    track: friend.track,
                    artist: friend.artist,
                    imageURL: friend.imageURL,
                    playedAt: friend.playedAt,
                    nowPlaying: inferredNowPlaying
                )
            }.sorted {
                if $0.nowPlaying != $1.nowPlaying {
                    return $0.nowPlaying && !$1.nowPlaying
                }
                let lhs = $0.playedAt ?? .distantPast
                let rhs = $1.playedAt ?? .distantPast
                return lhs > rhs
            }
            let nowCount = friendsListening.filter { inferredNowPlayingState(for: $0) }.count
            friendsStatus = "Loaded \(friendsListening.count) friends (\(nowCount) listening now)"
            scheduleSeparationRefresh()
        } catch is CancellationError {
            return
        } catch {
            handle(error: error)
            friendsStatus = "Failed to load friends"
        }
    }

    private func refreshNeighboursData() async {
        guard isAuthenticated else {
            neighboursStatus = "Sign in to load neighbours"
            neighbours = []
            return
        }
        neighboursStatus = "Loading neighbours..."
        lastAPIError = nil
        lastRecoveryHint = nil

        do {
            neighbours = try await api.fetchNeighbours(limit: 500)
            neighboursStatus = "Loaded \(neighbours.count) neighbours"
            scheduleSeparationRefresh()
        } catch is CancellationError {
            return
        } catch let LastfmAPIError.api(code, message)
            where code == 3 && message.localizedCaseInsensitiveContains("invalid method") {
            if friendsListening.isEmpty {
                await refreshFriendsData()
            }
            neighbours = fallbackNeighboursFromFriends(limit: 500)
            neighboursStatus = "Neighbours API unavailable; showing \(neighbours.count) friends as neighbours"
            scheduleSeparationRefresh()
        } catch {
            handle(error: error)
            neighboursStatus = "Failed to load neighbours"
        }
    }

    private func fallbackNeighboursFromFriends(limit: Int) -> [LastfmNeighbour] {
        let capped = min(max(1, limit), 1000)
        var seen: Set<String> = []
        var output: [LastfmNeighbour] = []
        output.reserveCapacity(min(capped, friendsListening.count))

        let sorted = friendsListening.sorted {
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

        for friend in sorted {
            let trimmedUser = friend.user.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUser.isEmpty else { continue }
            let key = trimmedUser.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(
                LastfmNeighbour(
                    id: "friend-\(key)",
                    user: trimmedUser,
                    realname: friend.realname,
                    country: friend.country,
                    isSubscriber: friend.isSubscriber,
                    accountType: friend.accountType,
                    avatarURL: friend.avatarURL,
                    profileURL: "https://www.last.fm/user/\(trimmedUser)",
                    matchScore: nil
                )
            )
            if output.count >= capped {
                break
            }
        }
        return output
    }

    private func scheduleSeparationRefresh() {
        separationTask?.cancel()
        separationTask = Task { @MainActor in
            await refreshSeparationDegrees()
        }
    }

    private func refreshSeparationDegrees() async {
        guard isAuthenticated else {
            separationByUser = [:]
            separationStatus = "Sign in to calculate separation"
            return
        }
        guard let source = api.sessionUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            separationByUser = [:]
            separationStatus = "No source user available"
            return
        }

        let targetUsers = visibleTargetUsers(source: source)
        guard !targetUsers.isEmpty else {
            separationByUser = [:]
            separationStatus = "No users to compare"
            return
        }

        separationStatus = "Calculating separation paths..."
        let results = await bfsDegrees(from: source, targets: targetUsers, maxDepth: quickSeparationDepth, includeContext: true)
        guard !Task.isCancelled else { return }
        separationByUser = results.degrees
        let found = results.degrees.count
        separationStatus = "Found paths for \(found)/\(targetUsers.count) users"
    }

    private func visibleTargetUsers(source: String) -> [String] {
        let sourceLower = source.lowercased()
        var seen: Set<String> = []
        var targets: [String] = []

        for user in friendsListening.map(\.user) + neighbours.map(\.user) {
            let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            guard lower != sourceLower else { continue }
            guard !seen.contains(lower) else { continue }
            seen.insert(lower)
            targets.append(trimmed)
            if targets.count >= 80 { break }
        }
        return targets
    }

    private func bfsDegrees(
        from source: String,
        targets: [String],
        maxDepth: Int,
        includeContext: Bool
    ) async -> (degrees: [String: Int], graph: SocialGraphSnapshot?) {
        var targetMap: [String: String] = [:]
        for item in targets {
            targetMap[item.lowercased()] = item
        }
        var pending = Set(targetMap.keys)
        let sourceLower = source.lowercased()
        var visited: Set<String> = [sourceLower]
        var queue: [(user: String, depth: Int)] = [(source, 0)]
        var found: [String: Int] = [:]
        var parentByUser: [String: String] = [:]
        var depthByUser: [String: Int] = [sourceLower: 0]
        var displayByUser: [String: String] = [sourceLower: source]
        let maxExploredNodes = includeContext ? 1200 : min(10_000, max(2_000, maxDepth * 500))

        while !queue.isEmpty && !pending.isEmpty {
            guard !Task.isCancelled else { break }
            let current = queue.removeFirst()
            if current.depth >= maxDepth { continue }
            if visited.count > maxExploredNodes { break }

            let neighbors = await friendsOf(user: current.user)
            for neighbor in neighbors {
                let lower = neighbor.lowercased()
                guard !visited.contains(lower) else { continue }
                visited.insert(lower)
                let nextDepth = current.depth + 1
                queue.append((neighbor, nextDepth))
                parentByUser[lower] = current.user.lowercased()
                depthByUser[lower] = nextDepth
                displayByUser[lower] = neighbor
                if pending.contains(lower) {
                    if let original = targetMap[lower] {
                        found[original.lowercased()] = nextDepth
                    }
                    pending.remove(lower)
                }
            }
        }
        let graph = makeSocialGraph(
            source: source,
            targetLowerSet: Set(targetMap.keys),
            parentByUser: parentByUser,
            depthByUser: depthByUser,
            displayByUser: displayByUser,
            includeContext: includeContext
        )
        return (found, graph)
    }

    private func friendsOf(user: String) async -> [String] {
        let key = user.lowercased()
        if let cached = friendGraphCache[key] {
            return cached
        }
        do {
            let fetched = try await api.fetchFriendUsernames(user: user, limit: 120)
            friendGraphCache[key] = fetched
            return fetched
        } catch {
            return []
        }
    }

    private func makeSocialGraph(
        source: String,
        targetLowerSet: Set<String>,
        parentByUser: [String: String],
        depthByUser: [String: Int],
        displayByUser: [String: String],
        includeContext: Bool
    ) -> SocialGraphSnapshot? {
        let sourceLower = source.lowercased()
        guard !depthByUser.isEmpty else { return nil }

        var selected: Set<String> = [sourceLower]
        for target in targetLowerSet where depthByUser[target] != nil {
            var cursor: String? = target
            while let current = cursor {
                if selected.contains(current) { break }
                selected.insert(current)
                cursor = parentByUser[current]
            }
        }

        let remainingCapacity = max(0, 220 - selected.count)
        if includeContext, remainingCapacity > 0 {
            let extras = depthByUser
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value < rhs.value }
                    return lhs.key < rhs.key
                }
                .map(\.key)
                .filter { !selected.contains($0) }
            for key in extras.prefix(remainingCapacity) {
                selected.insert(key)
            }
        }

        let nodes = selected.compactMap { lower -> SocialGraphNode? in
            guard let degree = depthByUser[lower] else { return nil }
            let display = displayByUser[lower] ?? lower
            return SocialGraphNode(
                id: lower,
                displayName: display,
                degree: degree,
                isTarget: targetLowerSet.contains(lower),
                isSource: lower == sourceLower
            )
        }
        .sorted {
            if $0.degree != $1.degree { return $0.degree < $1.degree }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let edges = selected.compactMap { child -> SocialGraphEdge? in
            guard let parent = parentByUser[child], selected.contains(parent) else { return nil }
            return SocialGraphEdge(id: "\(parent)->\(child)", from: parent, to: child)
        }

        return SocialGraphSnapshot(
            sourceUser: source,
            nodes: nodes,
            edges: edges,
            generatedAt: Date()
        )
    }

    private func isLikelyNowPlaying(playedAt: Date?) -> Bool {
        guard let playedAt else { return false }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= inferredNowPlayingWindow
    }

    private func inferredNowPlayingState(for friend: LastfmFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        return isLikelyNowPlaying(playedAt: friend.playedAt)
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    guard self.playbackState == "Playing" else { return }
                    let base = self.accumulatedPlayTime
                    if let start = self.currentTrackStart {
                        self.elapsedForCurrentTrack = base + max(0, Date().timeIntervalSince(start))
                        self.scrobbleProgress = self.progressValue(
                            elapsed: self.elapsedForCurrentTrack,
                            threshold: self.scrobbleThreshold
                        )
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startFriendsAutoRefresh() {
        friendsRefreshTask?.cancel()
        guard isAuthenticated else { return }
        friendsRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.isAuthenticated else { return }
                    Task { @MainActor in
                        await self.refreshFriendsData()
                    }
                }
            }
        }
    }

    private func progressValue(elapsed: TimeInterval, threshold: TimeInterval) -> Double {
        guard threshold > 0 else { return 0 }
        return min(1.0, max(0, elapsed / threshold))
    }

    private func validateSessionOnStartup() async {
        guard isAuthenticated else { return }
        do {
            let validation = try await api.validateSession()
            if validation.isValid {
                sessionStatus = "Session valid"
                capabilitiesStatus = formatCapabilities(validation.capabilities)
                isSubscriber = validation.capabilities.isSubscriber
                validationSource = validation.fromCache ? "Cache" : "Live"
            } else {
                signOut()
                sessionStatus = "Session invalid"
            }
        } catch {
            if error is CancellationError {
                return
            }
            handle(error: error)
            if let apiError = error as? LastfmAPIError, case .invalidSession = apiError {
                signOut()
                sessionStatus = "Session invalid"
                return
            }
            sessionStatus = "Validation failed"
        }
    }

    private func handle(error: Error) {
        if let apiError = error as? LastfmAPIError {
            lastAPIError = apiError.localizedDescription
            lastRecoveryHint = apiError.recoverySuggestion
        } else {
            lastAPIError = error.localizedDescription
            lastRecoveryHint = "Retry later. If this persists, verify API credentials and connectivity."
        }
    }

    private func formatCapabilities(_ capabilities: LastfmCapabilities) -> String {
        let tier = capabilities.isSubscriber ? "Subscriber" : "Standard"
        let radio = capabilities.canUseRadio ? "Radio on" : "Radio off"
        if let accountType = capabilities.accountType, !accountType.isEmpty {
            return "\(tier), \(radio), \(accountType)"
        }
        return "\(tier), \(radio)"
    }

    private func computeTracksPerDayAverage(_ profile: LastfmUserProfile) -> Int? {
        guard let playcount = profile.playcount,
              let registeredAt = profile.registeredAt else { return nil }
        let days = max(1, Int(Date().timeIntervalSince(registeredAt) / 86_400))
        return playcount / days
    }

    private func hydrateTopArtistImages(_ artists: [LastfmTopArtist]) async -> [LastfmTopArtist] {
        var hydrated: [LastfmTopArtist] = []
        hydrated.reserveCapacity(artists.count)
        for (index, artist) in artists.enumerated() {
            if artist.imageURL != nil || index >= 12 {
                hydrated.append(artist)
                continue
            }
            do {
                let detail = try await api.fetchArtistDetails(artist: artist.name)
                hydrated.append(
                    LastfmTopArtist(
                        id: artist.id,
                        name: artist.name,
                        playcount: artist.playcount,
                        imageURL: detail.imageURL,
                        url: artist.url
                    )
                )
            } catch {
                hydrated.append(artist)
            }
        }
        return hydrated
    }
}
