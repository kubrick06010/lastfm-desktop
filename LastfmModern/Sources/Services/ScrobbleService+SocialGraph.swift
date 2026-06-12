import Foundation

@MainActor
extension ScrobbleService {
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

    func fallbackNeighboursFromFriends(limit: Int) -> [LastfmNeighbour] {
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

    func scheduleSeparationRefresh() {
        separationTask?.cancel()
        separationTask = Task { @MainActor in
            await refreshSeparationDegrees()
        }
    }

    func refreshSeparationDegrees() async {
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

    func visibleTargetUsers(source: String) -> [String] {
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

    func bfsDegrees(
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

    func friendsOf(user: String) async -> [String] {
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

    func makeSocialGraph(
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

    func isLikelyNowPlaying(playedAt: Date?) -> Bool {
        guard let playedAt else { return false }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= inferredNowPlayingWindow
    }

    func inferredNowPlayingState(for friend: LastfmFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        return isLikelyNowPlaying(playedAt: friend.playedAt)
    }
}
