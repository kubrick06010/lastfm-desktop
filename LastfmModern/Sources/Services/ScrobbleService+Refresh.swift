import Foundation

@MainActor
extension ScrobbleService {
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

    func refreshExploreData(for track: Track) async {
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

    func refreshProfileData() async {
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

    func refreshScrobblesData() async {
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

    func refreshFriendsData() async {
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

    func refreshNeighboursData() async {
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

    func startFriendsAutoRefresh() {
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

    func computeTracksPerDayAverage(_ profile: LastfmUserProfile) -> Int? {
        guard let playcount = profile.playcount,
              let registeredAt = profile.registeredAt else { return nil }
        let days = max(1, Int(Date().timeIntervalSince(registeredAt) / 86_400))
        return playcount / days
    }

    func hydrateTopArtistImages(_ artists: [LastfmTopArtist]) async -> [LastfmTopArtist] {
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
