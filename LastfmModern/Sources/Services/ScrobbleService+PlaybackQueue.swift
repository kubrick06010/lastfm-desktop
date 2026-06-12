import Foundation

@MainActor
extension ScrobbleService {
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

    func handlePlayerEvent(_ event: PlayerEvent) {
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

    func handleTrackStarted(_ track: Track) {
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

    func handlePaused() {
        guard playbackState == "Playing" else { return }
        updateElapsedPlayTime()
        playbackState = "Paused"
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
    }

    func handleResumed() {
        guard playbackState == "Paused", currentTrack != nil else { return }
        playbackState = "Playing"
        currentTrackStart = .now
        scheduleThresholdCheck()
        scheduleNowPlayingIfNeeded()
        startProgressUpdates()
    }

    func handleStopped() {
        finalizeCurrentTrackIfNeeded()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
        resetPlaybackState()
    }

    func finalizeCurrentTrackIfNeeded() {
        updateElapsedPlayTime()
        guard let track = currentTrack else { return }

        if elapsedForCurrentTrack >= threshold(for: track) {
            queueIfEligible(track)
        }
    }

    func updateElapsedPlayTime() {
        guard let start = currentTrackStart else { return }
        accumulatedPlayTime += max(0, Date().timeIntervalSince(start))
        elapsedForCurrentTrack = accumulatedPlayTime
        scrobbleProgress = progressValue(elapsed: elapsedForCurrentTrack, threshold: scrobbleThreshold)
        currentTrackStart = nil
    }

    func scheduleThresholdCheck() {
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

    func queueIfEligible(_ track: Track) {
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

    func isTrackScrobblable(_ track: Track) -> Bool {
        guard !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard track.duration >= 30 else { return false }
        return true
    }

    func threshold(for track: Track) -> TimeInterval {
        min(240, max(30, track.duration * 0.5))
    }

    func persistQueue() {
        queueStore.save(queuedScrobbles)
    }

    func isRetryableSubmissionError(_ error: Error) -> Bool {
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

    func scheduleNowPlayingIfNeeded() {
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

    func scheduleRetryIfNeeded() {
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

    func cancelRetrySchedule() {
        retryTask?.cancel()
        retryTask = nil
        isRetryScheduled = false
        nextRetryAt = nil
    }

    func resetRetryBackoff() {
        cancelRetrySchedule()
        retryDelaySeconds = 2
    }

    func pruneRecentScrobbles() {
        let cutoff = Date().addingTimeInterval(-60 * 60)
        recentScrobbles = recentScrobbles.filter { $0.value >= cutoff }
    }

    func resetPlaybackState() {
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

    func startProgressUpdates() {
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

    func progressValue(elapsed: TimeInterval, threshold: TimeInterval) -> Double {
        guard threshold > 0 else { return 0 }
        return min(1.0, max(0, elapsed / threshold))
    }
}
