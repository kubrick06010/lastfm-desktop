import Foundation

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
    @Published private(set) var weeklyTopArtists: [LastfmTopArtist] = []
    @Published private(set) var overallTopArtists: [LastfmTopArtist] = []
    @Published private(set) var lovedTracksCount: Int?
    @Published private(set) var tracksPerDayAverage: Int?
    @Published private(set) var isSubscriber = false
    @Published private(set) var exploreStatus = "Waiting for track"
    @Published private(set) var profileStatus = "Not loaded"
    @Published private(set) var scrobblesStatus = "Not loaded"
    @Published private(set) var friendsStatus = "Not loaded"

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
    private var hasQueuedCurrentTrack = false
    private var hasSentNowPlayingForCurrentTrack = false
    private var recentScrobbles: [String: Date] = [:]
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
            scheduleRetryIfNeeded()
            await validateSessionOnStartup()
            await refreshProfileData()
            await refreshScrobblesData()
            await refreshFriendsData()
        } catch {
            handle(error: error)
            authError = lastAPIError
        }
    }

    func signOut() {
        api.clearSession()
        sessionStore.clear()
        isAuthenticated = false
        sessionStatus = "Not authenticated"
        capabilitiesStatus = "Unknown"
        validationSource = "Live"
        profile = nil
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectStatus = "Select a scrobble to inspect"
        latestScrobbles = []
        weeklyTopArtists = []
        overallTopArtists = []
        lovedTracksCount = nil
        tracksPerDayAverage = nil
        profileStatus = "Not loaded"
        scrobblesStatus = "Not loaded"
        isSubscriber = false
        friendsListening = []
        friendsStatus = "Not loaded"
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

    func inspect(track: String, artist: String) async {
        guard isAuthenticated else {
            inspectStatus = "Sign in to inspect tracks"
            inspectedTrackDetails = nil
            inspectedArtistDetails = nil
            return
        }
        inspectStatus = "Loading detail..."
        lastAPIError = nil
        lastRecoveryHint = nil

        var loadedAnything = false

        do {
            inspectedTrackDetails = try await api.fetchTrackDetails(artist: artist, track: track)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            inspectedTrackDetails = nil
            handle(error: error)
        }

        do {
            inspectedArtistDetails = try await api.fetchArtistDetails(artist: artist)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            inspectedArtistDetails = nil
            handle(error: error)
        }

        inspectStatus = loadedAnything ? "Loaded" : "Failed to load detail"
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

    func submitQueued() async {
        guard scrobblingEnabled, isAuthenticated else {
            cancelRetrySchedule()
            return
        }
        cancelRetrySchedule()
        queueSubmitAttempts += 1
        lastAPIError = nil
        var failedIndex: Int?

        for (index, track) in queuedScrobbles.enumerated() {
            do {
                try await api.scrobble(track)
                recentScrobbles[track.fingerprint] = .now
            } catch {
                failedIndex = index
                queueSubmitFailures += 1
                handle(error: error)
                break
            }
        }

        if let failedIndex {
            queuedScrobbles = Array(queuedScrobbles.suffix(from: failedIndex))
            scheduleRetryIfNeeded()
        } else {
            queuedScrobbles.removeAll()
            lastSubmittedAt = .now
            resetRetryBackoff()
        }
        persistQueue()
    }

    func queueCurrentTrack() {
        guard let currentTrack, scrobblingEnabled else { return }
        queueIfEligible(currentTrack)
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
            overallTopArtists = []
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
                async let weekly = api.fetchTopArtists(period: .week, limit: 6)
                async let overall = api.fetchTopArtists(period: .overall, limit: 8)
                async let lovedCount = api.fetchLovedTracksCount()
                self.profile = profile
                let weeklyBase = try await weekly
                let overallBase = try await overall
                self.weeklyTopArtists = await self.hydrateTopArtistImages(weeklyBase)
                self.overallTopArtists = await self.hydrateTopArtistImages(overallBase)
                self.lovedTracksCount = try await lovedCount
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
            latestScrobbles = try await api.fetchRecentScrobbles(limit: 50)
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
            friendsListening = try await api.fetchFriendsListening(limit: 200).sorted {
                if $0.nowPlaying != $1.nowPlaying {
                    return $0.nowPlaying && !$1.nowPlaying
                }
                let lhs = $0.playedAt ?? .distantPast
                let rhs = $1.playedAt ?? .distantPast
                return lhs > rhs
            }
            let nowCount = friendsListening.filter(\.nowPlaying).count
            friendsStatus = "Loaded (\(nowCount) listening now)"
        } catch is CancellationError {
            return
        } catch {
            handle(error: error)
            friendsStatus = "Failed to load friends"
        }
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
        for artist in artists {
            if artist.imageURL != nil {
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
