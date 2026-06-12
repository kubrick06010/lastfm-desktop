import Foundation

@MainActor
final class ScrobbleService: ObservableObject {
    @Published var currentTrack: Track?
    @Published var queuedScrobbles: [Track] = []
    @Published var scrobblingEnabled = true
    @Published var isAuthenticated = false
    @Published var apiConfigured = false
    @Published var backendName = "Stub"
    @Published var authError: String?
    @Published var lastAPIError: String?
    @Published var monitorStatus = ""
    @Published var playbackState = "Stopped"
    @Published var lastSubmittedAt: Date?
    @Published var queueFilePath = ""
    @Published var sessionStatus = "Not authenticated"
    @Published var sessionUsername: String?
    @Published var storedAccounts: [LastfmSession] = []
    @Published var capabilitiesStatus = "Unknown"
    @Published var validationSource = "Live"
    @Published var lastRecoveryHint: String?
    @Published var elapsedForCurrentTrack: TimeInterval = 0
    @Published var scrobbleThreshold: TimeInterval = 0
    @Published var scrobbleProgress: Double = 0
    @Published var retryDelaySeconds = 2
    @Published var isRetryScheduled = false
    @Published var nextRetryAt: Date?
    @Published var nowPlayingDelaySeconds = 10
    @Published var queueSubmitAttempts = 0
    @Published var queueSubmitFailures = 0
    @Published var playerEventCount = 0
    @Published var currentTrackDetails: LastfmTrackDetails?
    @Published var currentArtistDetails: LastfmArtistDetails?
    @Published var inspectedTrackDetails: LastfmTrackDetails?
    @Published var inspectedArtistDetails: LastfmArtistDetails?
    @Published var inspectedSimilarTracks: [LastfmSimilarTrack] = []
    @Published var inspectedSimilarAlbums: [LastfmSimilarAlbum] = []
    @Published var inspectStatus = "Select a scrobble to inspect"
    @Published var profile: LastfmUserProfile?
    @Published var latestScrobbles: [LastfmRecentScrobble] = []
    @Published var friendsListening: [LastfmFriendListening] = []
    @Published var neighbours: [LastfmNeighbour] = []
    @Published var separationByUser: [String: Int] = [:]
    @Published var separationStatus = "Not calculated"
    @Published var socialGraph: SocialGraphSnapshot?
    @Published var weeklyTopArtists: [LastfmTopArtist] = []
    @Published var monthlyTopArtists: [LastfmTopArtist] = []
    @Published var yearlyTopArtists: [LastfmTopArtist] = []
    @Published var overallTopArtists: [LastfmTopArtist] = []
    @Published var globalTopArtistNames: [String] = []
    @Published var lovedTracksCount: Int?
    @Published var tracksPerDayAverage: Int?
    @Published var isSubscriber = false
    @Published var exploreStatus = "Waiting for track"
    @Published var profileStatus = "Not loaded"
    @Published var scrobblesStatus = "Not loaded"
    @Published var friendsStatus = "Not loaded"
    @Published var neighboursStatus = "Not loaded"

    var api: LastfmAPI
    let monitor: PlayerMonitor
    let sessionStore: LastfmAccountsStoring
    let queueStore: ScrobbleQueueStoring

    var currentTrackStart: Date?
    var accumulatedPlayTime: TimeInterval = 0
    var thresholdTask: Task<Void, Never>?
    var nowPlayingTask: Task<Void, Never>?
    var retryTask: Task<Void, Never>?
    var progressTask: Task<Void, Never>?
    var exploreTask: Task<Void, Never>?
    var profileTask: Task<Void, Never>?
    var friendsRefreshTask: Task<Void, Never>?
    var separationTask: Task<Void, Never>?
    var hasQueuedCurrentTrack = false
    var hasSentNowPlayingForCurrentTrack = false
    var recentScrobbles: [String: Date] = [:]
    var friendGraphCache: [String: [String]] = [:]
    let inferredNowPlayingWindow: TimeInterval = 30 * 60
    let quickSeparationDepth = 6
    let detailedSeparationDepth = 24
    let retryJitter: () -> Double
    let sleepFunction: @Sendable (UInt64) async -> Void

    init(
        api: LastfmAPI? = nil,
        monitor: PlayerMonitor = makeDefaultPlayerMonitor(),
        sessionStore: LastfmAccountsStoring = LastfmSessionStore(),
        queueStore: ScrobbleQueueStoring = ScrobbleQueueStore(),
        retryJitter: @escaping () -> Double = { Double.random(in: 0.85...1.15) },
        sleepFunction: @escaping @Sendable (UInt64) async -> Void = { nanos in
            try? await Task.sleep(nanoseconds: nanos)
        }
    ) {
        if let api {
            self.api = api
        } else if let config = LastfmAPIConfig.fromEnvironment() {
            self.api = LastfmAPIClient(
                config: config,
                sessionProvider: {
                    URLSession.lastfmSession(proxySettings: ProxySettingsStore().load())
                }
            )
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
        self.storedAccounts = sessionStore.allSessions()

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

}
