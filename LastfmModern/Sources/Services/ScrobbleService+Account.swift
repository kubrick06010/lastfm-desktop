import Foundation

@MainActor
extension ScrobbleService {
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
            storedAccounts = sessionStore.allSessions()
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
        storedAccounts = sessionStore.allSessions()
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

    func switchAccount(username: String) async {
        guard let targetSession = sessionStore.allSessions().first(where: {
            $0.name.caseInsensitiveCompare(username) == .orderedSame
        }) else {
            return
        }
        sessionStore.setActive(username: targetSession.name)
        api.restoreSession(targetSession)
        storedAccounts = sessionStore.allSessions()
        isAuthenticated = api.isAuthenticated
        sessionUsername = targetSession.name
        authError = nil
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
    }

    func removeAccount(username: String) async {
        let removingActive = sessionUsername?.caseInsensitiveCompare(username) == .orderedSame
        sessionStore.remove(username: username)
        storedAccounts = sessionStore.allSessions()

        guard removingActive else { return }

        api.clearSession()
        if let nextSession = sessionStore.load() {
            api.restoreSession(nextSession)
            isAuthenticated = api.isAuthenticated
            sessionUsername = nextSession.name
            authError = nil
            await validateSessionOnStartup()
            await refreshProfileData()
            await refreshScrobblesData()
            await refreshFriendsData()
            await refreshNeighboursData()
            startFriendsAutoRefresh()
        } else {
            isAuthenticated = false
            sessionUsername = nil
            sessionStatus = "Not authenticated"
            capabilitiesStatus = "Unknown"
            validationSource = "Live"
            profile = nil
            latestScrobbles = []
            friendsListening = []
            neighbours = []
            weeklyTopArtists = []
            monthlyTopArtists = []
            yearlyTopArtists = []
            overallTopArtists = []
            globalTopArtistNames = []
            lovedTracksCount = nil
            tracksPerDayAverage = nil
            profileStatus = "Not loaded"
            scrobblesStatus = "Not loaded"
            friendsStatus = "Not loaded"
            neighboursStatus = "Not loaded"
            isSubscriber = false
        }
    }

    func validateSessionOnStartup() async {
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

    func handle(error: Error) {
        if let apiError = error as? LastfmAPIError {
            lastAPIError = apiError.localizedDescription
            lastRecoveryHint = apiError.recoverySuggestion
        } else {
            lastAPIError = error.localizedDescription
            lastRecoveryHint = "Retry later. If this persists, verify API credentials and connectivity."
        }
    }

    func formatCapabilities(_ capabilities: LastfmCapabilities) -> String {
        let tier = capabilities.isSubscriber ? "Subscriber" : "Standard"
        let radio = capabilities.canUseRadio ? "Radio on" : "Radio off"
        if let accountType = capabilities.accountType, !accountType.isEmpty {
            return "\(tier), \(radio), \(accountType)"
        }
        return "\(tier), \(radio)"
    }
}
