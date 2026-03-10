import SwiftUI
import WebKit

private enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard = "Dashboard"
    case queue = "Queue"
    case profile = "Profile"
    case scrobbles = "Scrobbles"
    case reports = "Reports"
    case charts = "Charts"
    case friends = "Friends"
    case neighbours = "Neighbours"
    case account = "Account"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard:
            return "rectangle.3.group.bubble.left"
        case .queue:
            return "text.line.first.and.arrowtriangle.forward"
        case .profile:
            return "person.2.wave.2"
        case .scrobbles:
            return "music.note.list"
        case .reports:
            return "chart.pie.fill"
        case .charts:
            return "list.number"
        case .friends:
            return "person.3.sequence"
        case .neighbours:
            return "person.3.fill"
        case .account:
            return "person.crop.circle"
        }
    }
}

private struct DeepLinkTarget: Identifiable, Equatable {
    let id: String
    let scrobble: LastfmRecentScrobble
}

private struct SocialGraphTarget: Identifiable, Equatable {
    let id: String
    let user: String
    let profileURL: String?
}

struct ContentView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var selectedTab: WorkspaceTab? = .dashboard
    @State private var username = ""
    @State private var password = ""
    @State private var friendsQuery = ""
    @State private var neighboursQuery = ""
    @State private var scrobblesQuery = ""
    @State private var deepLinkTarget: DeepLinkTarget?
    @State private var socialGraphTarget: SocialGraphTarget?
    @State private var selectedProfileURL: URL?
    @State private var isDiagnosticsPresented = false

    var body: some View {
        NavigationSplitView {
            List(WorkspaceTab.allCases, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol)
                        .tag(tab)
                        .font(.custom("Avenir Next Medium", size: 13))
            }
            .navigationTitle("Last.fm modern")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Last.fm Scrobbler")
                            .font(.custom("Avenir Next Medium", size: 21))
                        Text(nowPlayingSubtitle)
                            .font(.custom("Avenir Next Medium", size: 13))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.28))

                ZStack {
                    AppBackdrop()
                    switch selectedTab ?? .dashboard {
                    case .dashboard:
                        DashboardView { track, artist, imageURL in
                            openDeepLink(track: track, artist: artist, imageURL: imageURL)
                        }
                    case .queue:
                        QueueView()
                    case .profile:
                        ProfileView()
                    case .scrobbles:
                        ScrobblesView(query: $scrobblesQuery) { item in
                            openDeepLink(scrobble: item)
                        }
                    case .reports:
                        ReportsView()
                    case .charts:
                        ChartsView(
                            onOpenTrack: { track, artist in
                                openDeepLink(track: track, artist: artist)
                            },
                            onOpenArtist: { artist in
                                openDeepLink(track: nil, artist: artist)
                            }
                        )
                    case .friends:
                        FriendsView(
                            query: $friendsQuery,
                            onOpenFriendTrack: { friend in
                                if let track = friend.track, let artist = friend.artist {
                                    openDeepLink(track: track, artist: artist, imageURL: friend.imageURL)
                                }
                            },
                            onOpenGraph: { friend in
                                openSocialGraph(forUser: friend.user, profileURL: "https://www.last.fm/user/\(friend.user)")
                            }
                        )
                    case .neighbours:
                        NeighboursView(query: $neighboursQuery) { neighbour in
                            openSocialGraph(for: neighbour)
                        }
                    case .account:
                        AccountView(username: $username, password: $password)
                    }

                    if let deepLinkTarget {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    self.deepLinkTarget = nil
                                    scrobbleService.clearInspection()
                                }
                            }

                        VStack {
                            HStack {
                                Spacer()
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.22)) {
                                                    self.deepLinkTarget = nil
                                                    scrobbleService.clearInspection()
                                                }
                                            } label: {
                                                Label("Back", systemImage: "chevron.left")
                                                    .font(.custom("Avenir Next Medium", size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            Spacer()
                                        }

                                        ScrobbleDetailPanel(item: deepLinkTarget.scrobble)
                                            .appPanelStyle()
                                    }
                                    .padding(16)
                                }
                                .frame(width: 460)
                                .background(.ultraThinMaterial)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                        }
                        .animation(.easeInOut(duration: 0.22), value: deepLinkTarget.id)
                    }

                    if let socialGraphTarget {
                        Color.black.opacity(0.35)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    self.socialGraphTarget = nil
                                    self.selectedProfileURL = nil
                                }
                            }

                        VStack {
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                self.socialGraphTarget = nil
                                                self.selectedProfileURL = nil
                                            }
                                        } label: {
                                            Label("Back", systemImage: "chevron.left")
                                                .font(.custom("Avenir Next Medium", size: 14))
                                        }
                                        .buttonStyle(.plain)
                                        Spacer()
                                        Text("Separation Graph: \(socialGraphTarget.user)")
                                            .font(.custom("Avenir Next Demi Bold", size: 16))
                                    }

                                    Text(scrobbleService.separationStatus)
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)

                                    if let graph = scrobbleService.socialGraph, !graph.nodes.isEmpty {
                                        InteractiveSeparationGraphView(graph: graph) { username in
                                            selectedProfileURL = userProfileURL(username: username)
                                        }
                                        .frame(height: 300)
                                        .appPanelStyle()
                                    } else {
                                        Text("No graph data available.")
                                            .font(.custom("Avenir Next Medium", size: 12))
                                            .foregroundStyle(.secondary)
                                            .appPanelStyle()
                                    }

                                    if let selectedProfileURL {
                                        ProfileWebView(url: selectedProfileURL)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    } else {
                                        Text("Click a node to open profile in-app.")
                                            .font(.custom("Avenir Next Medium", size: 12))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            .appPanelStyle()
                                    }
                                }
                                .padding(16)
                                .frame(width: 760, height: 760)
                                .background(.ultraThinMaterial)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                        }
                        .animation(.easeInOut(duration: 0.22), value: socialGraphTarget.id)
                    }
                }

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape.fill")
                        Text("\(scrobbleService.profile?.name ?? "Guest") (\(scrobbleService.isAuthenticated ? "Online" : "Offline"))")
                            .font(.custom("Avenir Next Medium", size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.35))

                    BottomTabShell(selectedTab: Binding(
                        get: { selectedTab ?? .scrobbles },
                        set: { selectedTab = $0 }
                    ))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.showDiagnostics)) { _ in
            isDiagnosticsPresented = true
        }
        .sheet(isPresented: $isDiagnosticsPresented) {
            DiagnosticsView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 680, minHeight: 520)
        }
    }

    private var nowPlayingSubtitle: String {
        if let current = scrobbleService.currentTrack {
            return "\(current.artist) - \(current.title)"
        }
        return "No track playing"
    }

    private func openDeepLink(scrobble: LastfmRecentScrobble) {
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(id: scrobble.id, scrobble: scrobble)
        }
        Task {
            await scrobbleService.inspect(scrobble: scrobble)
        }
    }

    private func openDeepLink(track: String?, artist: String, imageURL: String? = nil) {
        let title = track?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? track! : artist
        let item = LastfmRecentScrobble(
            id: "deep-\(artist)|\(title)",
            track: title,
            artist: artist,
            album: nil,
            imageURL: imageURL,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false
        )
        openDeepLink(scrobble: item)
    }

    private func openSocialGraph(for neighbour: LastfmNeighbour) {
        openSocialGraph(forUser: neighbour.user, profileURL: neighbour.profileURL)
    }

    private func openSocialGraph(forUser user: String, profileURL: String?) {
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = nil
            socialGraphTarget = SocialGraphTarget(
                id: user.lowercased(),
                user: user,
                profileURL: profileURL
            )
            selectedProfileURL = profileURLString(profileURL, fallbackUser: user)
        }
        Task {
            await scrobbleService.prepareSocialGraph(for: user)
        }
    }

    private func profileURLString(_ raw: String?, fallbackUser: String) -> URL? {
        if let raw, let url = URL(string: raw) {
            return url
        }
        return userProfileURL(username: fallbackUser)
    }

    private func userProfileURL(username: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? username
        return URL(string: "https://www.last.fm/user/\(encoded)")
    }
}

private struct BottomTabShell: View {
    @Binding var selectedTab: WorkspaceTab
    private let tabs: [WorkspaceTab] = [.scrobbles, .reports, .charts]
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.custom("Avenir Next Medium", size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedTab == tab ? accent : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.9), Color(red: 0.12, green: 0.13, blue: 0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let onOpenTrackDetail: (_ track: String, _ artist: String, _ imageURL: String?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Listening Dashboard")
                    .font(.custom("Avenir Next Medium", size: 24))
                    .foregroundStyle(.primary)

                if let nowPlaying = scrobbleService.currentTrack {
                    ZStack {
                        dashboardBackgroundArt(
                            dashboardHeroImageURL
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Label {
                                    Text("Scrobbling from \(nowPlaying.sourceApp ?? "Music")")
                                        .font(.custom("Avenir Next Medium", size: 15))
                                } icon: {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                Spacer()
                                dashboardMiniProgress
                            }

                            Divider().overlay(Color.white.opacity(0.10))

                            HStack(alignment: .top, spacing: 14) {
                                dashboardArt(dashboardTrackImageURL, size: 132)
                                    .onTapGesture {
                                        openDetailForCurrentTrack(nowPlaying)
                                    }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(scrobbleService.currentTrackDetails?.name ?? nowPlaying.title)
                                        .font(.custom("Avenir Next Demi Bold", size: 28))
                                        .lineLimit(3)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            openDetailForCurrentTrack(nowPlaying)
                                        }
                                        .simultaneousGesture(
                                            MagnificationGesture()
                                                .onEnded { value in
                                                    guard value > 1.05 else { return }
                                                    openDetailForCurrentTrack(nowPlaying)
                                                }
                                        )
                                    Text("by \(scrobbleService.currentTrackDetails?.artist ?? nowPlaying.artist)")
                                        .font(.custom("Avenir Next Demi Bold", size: 18))
                                        .foregroundStyle(.secondary)
                                    if let album = scrobbleService.currentTrackDetails?.album ?? nowPlaying.album {
                                        Text("from \(album)")
                                            .font(.custom("Avenir Next Medium", size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                    HStack(spacing: 14) {
                                        Image(systemName: "heart")
                                        Image(systemName: "tag")
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                                }
                                Spacer()
                            }

                            trackInsightsCard

                            Divider().overlay(Color.white.opacity(0.10))

                            VStack(alignment: .leading, spacing: 10) {
                                Text(scrobbleService.currentArtistDetails?.name ?? nowPlaying.artist)
                                    .font(.custom("Avenir Next Demi Bold", size: 22))

                                HStack(alignment: .top, spacing: 14) {
                                    dashboardArt(scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL, size: 126)
                                    Text(artistSummaryText)
                                        .font(.custom("Avenir Next Regular", size: 15))
                                        .lineLimit(6)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                HStack(spacing: 0) {
                                    statColumn("Listeners", scrobbleService.currentArtistDetails?.listeners)
                                    statColumn("Plays", scrobbleService.currentArtistDetails?.playcount)
                                    statColumn("Plays in your library", scrobbleService.currentTrackDetails?.userPlaycount)
                                }
                                .overlay {
                                    HStack {
                                        Divider().frame(height: 36)
                                        Spacer()
                                        Divider().frame(height: 36)
                                    }
                                    .padding(.horizontal, 12)
                                    .opacity(0.35)
                                }

                                if let tags = scrobbleService.currentArtistDetails?.tags, !tags.isEmpty {
                                    Text("Popular tags: \(tags.prefix(6).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 14))
                                        .foregroundStyle(.secondary)
                                }

                                if let similar = scrobbleService.currentArtistDetails?.similarArtists, !similar.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Similar Artists")
                                            .font(.custom("Avenir Next Demi Bold", size: 18))
                                        ScrollView(.horizontal, showsIndicators: false) {
                                            HStack(spacing: 18) {
                                                ForEach(similar.prefix(6), id: \.name) { item in
                                                    VStack(alignment: .leading, spacing: 6) {
                                                        dashboardArt(item.imageURL, size: 72)
                                                        Text(item.name)
                                                            .font(.custom("Avenir Next Medium", size: 14))
                                                            .lineLimit(1)
                                                    }
                                                    .frame(width: 90, alignment: .leading)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                } else {
                    Text("No track detected.")
                        .font(.custom("Avenir Next Medium", size: 14))
                        .foregroundStyle(.secondary)
                        .padding(20)
                        .appPanelStyle()
                }

                HStack(spacing: 12) {
                    MetricCard(title: "Queued", value: "\(scrobbleService.queuedScrobbles.count)", icon: "shippingbox")
                    MetricCard(title: "Failures", value: "\(scrobbleService.queueSubmitFailures)", icon: "exclamationmark.triangle")
                    MetricCard(title: "Events", value: "\(scrobbleService.playerEventCount)", icon: "waveform")
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: scrobbleService.queuedScrobbles.count)
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func dashboardArt(_ urlString: String?, size: CGFloat = 120) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func dashboardBackgroundArt(_ urlString: String?) -> some View {
        ZStack {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 30)
                            .saturation(0.65)
                            .opacity(0.42)
                    default:
                        Color.clear
                    }
                }
            }
            // Subtle bokeh highlights.
            Circle()
                .fill(Color.white.opacity(0.09))
                .frame(width: 260, height: 260)
                .blur(radius: 22)
                .offset(x: 160, y: -80)
            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: -180, y: 60)
            LinearGradient(
                colors: [Color.black.opacity(0.24), Color.black.opacity(0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
    }

    private var playbackChip: some View {
        Text(scrobbleService.playbackState)
            .font(.custom("Avenir Next Medium", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(scrobbleService.playbackState == "Playing" ? .green : .secondary)
            .background(
                (scrobbleService.playbackState == "Playing" ? Color.green : Color.white)
                    .opacity(0.12),
                in: Capsule()
            )
    }

    private var dashboardMiniProgress: some View {
        VStack(alignment: .trailing, spacing: 4) {
            playbackChip
            ProgressView(value: scrobbleService.scrobbleProgress, total: 1)
                .frame(width: 90)
                .progressViewStyle(.linear)
            Text("\(Int(scrobbleService.elapsedForCurrentTrack))s / \(Int(scrobbleService.scrobbleThreshold))s")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private var trackInsightsCard: some View {
        // Mirrors the legacy client "you listened X times" callout while gracefully
        // degrading when Last.fm omits user-specific counters.
        Text("You've listened to \(scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist ?? "this artist") \(count(scrobbleService.currentArtistDetails?.userPlaycount)) times and \(scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title ?? "this track") \(count(scrobbleService.currentTrackDetails?.userPlaycount)) time(s).")
            .font(.custom("Avenir Next Medium", size: 14))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var artistSummaryText: String {
        if let summary = scrobbleService.currentArtistDetails?.summary, !summary.isEmpty {
            return summary
        }
        return "Artist biography and stats are temporarily unavailable."
    }

    private func statColumn(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(count(value))
                .font(.custom("Avenir Next Demi Bold", size: 20))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openDetailForCurrentTrack(_ nowPlaying: Track) {
        onOpenTrackDetail(
            scrobbleService.currentTrackDetails?.name ?? nowPlaying.title,
            scrobbleService.currentTrackDetails?.artist ?? nowPlaying.artist,
            dashboardTrackImageURL
        )
    }

    private var dashboardHeroImageURL: String? {
        // Prefer artist hero art for background bokeh; fallback to resolved track artwork.
        scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL
    }

    private var dashboardTrackImageURL: String? {
        // Artwork resolution chain:
        // 1) track.getInfo image
        // 2) matching recent scrobble image (same title + artist)
        // 3) artist image as final fallback.
        if let explicit = scrobbleService.currentTrackDetails?.imageURL, !explicit.isEmpty {
            return explicit
        }
        guard let now = scrobbleService.currentTrack else {
            return scrobbleService.currentArtistDetails?.imageURL
        }
        let normalizedTitle = now.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = now.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let matched = scrobbleService.latestScrobbles.first(where: {
            $0.track.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle &&
            $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedArtist &&
            ($0.imageURL?.isEmpty == false)
        })?.imageURL {
            return matched
        }
        return scrobbleService.currentArtistDetails?.imageURL
    }

    private func count(_ value: Int?) -> String {
        value.map { $0.formatted() } ?? "—"
    }
}

private struct QueueView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scrobble Queue")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Spacer()
                Text("\(scrobbleService.queuedScrobbles.count) items")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }

            if scrobbleService.queuedScrobbles.isEmpty {
                Text("Queue is empty. Tracks that pass threshold rules will appear here.")
                    .font(.custom("Avenir Next Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appPanelStyle()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(scrobbleService.queuedScrobbles) { track in
                            HStack(spacing: 10) {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title).font(.custom("Avenir Next Medium", size: 14))
                                    Text(track.artist).font(.custom("Avenir Next Regular", size: 13)).foregroundStyle(.secondary)
                                    if let album = track.album, !album.isEmpty {
                                        Text(album).font(.custom("Avenir Next Regular", size: 12)).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(track.startedAt.formatted(date: .omitted, time: .shortened))
                                    .font(.custom("Avenir Next Regular", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(10)
                            .appPanelStyle()
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct AccountView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var username: String
    @Binding var password: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account And Session")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack {
                        Button("Sign In") {
                            Task { await scrobbleService.signIn(username: username, password: password) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Sign Out") {
                            scrobbleService.signOut()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend: \(scrobbleService.backendName)")
                    Text("Auth State: \(scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")")
                    Text("Session: \(scrobbleService.sessionStatus)")
                    Text("Capabilities: \(scrobbleService.capabilitiesStatus)")
                    Text("Operational errors: Tools > Diagnostics")
                        .foregroundStyle(.secondary)
                }
                .font(.custom("Avenir Next Medium", size: 13))
                .appPanelStyle()

                if let authError = scrobbleService.authError {
                    Text(authError)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.red)
                        .padding(10)
                        .appPanelStyle()
                }
            }
            .padding(24)
        }
    }
}

private struct ExploreView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Track And Artist Explore")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshExplore() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.exploreStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let track = scrobbleService.currentTrackDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            trackArt(track.imageURL)
                            VStack(alignment: .leading, spacing: 5) {
                                detailRow("Track", track.name)
                                detailRow("Artist", track.artist)
                                if let album = track.album {
                                    detailRow("Album", album)
                                }
                                detailRow("Listeners", formatCount(track.listeners))
                                detailRow("Playcount", formatCount(track.playcount))
                                if let user = track.userPlaycount {
                                    detailRow("Your Plays", "\(user)")
                                }
                                if !track.tags.isEmpty {
                                    Text("Tags: \(track.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = track.summary {
                            Text(summary)
                                .font(.custom("Avenir Next Regular", size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(4)
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No track details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artist = scrobbleService.currentArtistDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            trackArt(artist.imageURL)
                            VStack(alignment: .leading, spacing: 4) {
                                detailRow("Artist", artist.name)
                                detailRow("Listeners", formatCount(artist.listeners))
                                detailRow("Playcount", formatCount(artist.playcount))
                                if let user = artist.userPlaycount {
                                    detailRow("In your library", "\(user)")
                                }
                                if !artist.tags.isEmpty {
                                    Text("Tags: \(artist.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = artist.summary {
                            Text(summary)
                                .font(.custom("Avenir Next Regular", size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(5)
                        }
                        if !artist.similarArtists.isEmpty {
                            Text("Similar Artists")
                                .font(.custom("Avenir Next Medium", size: 12))
                            HStack(spacing: 12) {
                                ForEach(artist.similarArtists.prefix(4)) { similar in
                                    VStack(alignment: .leading, spacing: 3) {
                                        trackArt(similar.imageURL, size: 54)
                                        Text(similar.name)
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No artist details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.custom("Avenir Next Medium", size: 12))
    }

    private func formatCount(_ value: Int?) -> String {
        guard let value else { return "Unknown" }
        return value.formatted()
    }

    @ViewBuilder
    private func trackArt(_ urlString: String?, size: CGFloat = 110) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Profile")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshProfile() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.profileStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let profile = scrobbleService.profile {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 6) {
                            profileAvatar(profile.imageURL)
                            if let accountBadge = accountBadgeType(profile: profile) {
                                badgeView(accountBadge, fontSize: 10, horizontal: 8, vertical: 3)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name)
                                .font(.custom("Avenir Next Demi Bold", size: 22))
                            if let realname = profile.realname, !realname.isEmpty {
                                Text(realname)
                                    .font(.custom("Avenir Next Medium", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 14) {
                                profilePill("Tracks", profile.trackCount)
                                profilePill("Artists", profile.artistCount)
                                profilePill("Albums", profile.albumCount)
                                profilePill("Plays", profile.playcount)
                                profilePill("Loved", scrobbleService.lovedTracksCount)
                            }
                            if let registered = profile.registeredAt {
                                Text("Scrobbles since \(registered.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No profile loaded.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artistCount = profileArtistCount, let avg = scrobbleService.tracksPerDayAverage {
                    Text("You have \(artistCount.formatted()) artists in your library and on average listen to \(avg.formatted()) tracks per day.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .appPanelStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists This Week")
                    .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.weeklyTopArtists.isEmpty {
                        Text("No weekly top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.weeklyTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                artistImage(artist.imageURL, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: 13))
                                    Text("\((artist.playcount ?? 0).formatted()) plays")
                                        .font(.custom("Avenir Next Regular", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                                bar(artist.playcount, max: weeklyMax)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists Overall")
                        .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.overallTopArtists.isEmpty {
                        Text("No overall top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.overallTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    artistImage(artist.imageURL, size: 24)
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Regular", size: 12))
                                    Spacer()
                                    Text((artist.playcount ?? 0).formatted())
                                        .font(.custom("Avenir Next Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                bar(artist.playcount, max: overallMax)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func profilePill(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text((value ?? 0).formatted())
                .font(.custom("Avenir Next Medium", size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bar(_ value: Int?, max: Int) -> some View {
        let ratio = max > 0 ? Double(value ?? 0) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 12)
    }

    @ViewBuilder
    private func artistImage(_ urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "music.mic")
                    .font(.system(size: max(10, size * 0.35)))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func profileAvatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AnimatedAvatarImage(
                urls: animatedAvatarCandidates(for: url),
                size: 56
            )
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
        }
    }

    private func animatedAvatarCandidates(for baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        // Last.fm often exposes avatar PNG URLs that redirect to GIF when animated.
        // Trying GIF first avoids rendering static avatars for animated profiles.
        let path = baseURL.path.lowercased()
        if path.contains("/avatar"), path.hasSuffix(".png") {
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            let gifPath = baseURL.path.replacingOccurrences(of: ".png", with: ".gif")
            comps?.path = gifPath
            if let gifURL = comps?.url {
                candidates.append(gifURL)
            }
        }
        candidates.append(baseURL)
        return candidates
    }

    private var weeklyMax: Int {
        scrobbleService.weeklyTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var overallMax: Int {
        scrobbleService.overallTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var profileArtistCount: Int? {
        scrobbleService.profile?.artistCount
    }

    private func accountBadgeType(profile: LastfmUserProfile) -> String? {
        if let raw = profile.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty {
            return raw
        }
        return scrobbleService.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = normalized == "alum" ? "ALUM" : "LAST.FM PRO"
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct ScrobblesView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenDetail: (LastfmRecentScrobble) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your Scrobbles")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshScrobbles() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter scrobbles", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.scrobblesStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredScrobbles.isEmpty {
                    Text("No recent scrobbles available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredScrobbles) { item in
                            HStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    scrobbleArtwork(item.imageURL, nowPlaying: item.nowPlaying)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.track)
                                            .font(.custom("Avenir Next Medium", size: 13))
                                        Text(item.artist)
                                            .font(.custom("Avenir Next Regular", size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenDetail(item)
                                }

                                Spacer()

                                HStack(spacing: 10) {
                                    Button {
                                        Task { await scrobbleService.toggleLove(scrobble: item) }
                                    } label: {
                                        Image(systemName: item.loved ? "heart.fill" : "heart")
                                    }
                                    .buttonStyle(.plain)

                                    Button {
                                        openSearchTag(item)
                                    } label: {
                                        Image(systemName: "tag")
                                    }
                                    .buttonStyle(.plain)

                                    if let url = externalURL(for: item) {
                                        Button {
                                            openURL(url)
                                        } label: {
                                            Image(systemName: "arrow.up.right.square")
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)

                                Text(item.nowPlaying ? "Now" : (item.playedAt?.formatted(date: .omitted, time: .shortened) ?? "-"))
                                    .font(.custom("Avenir Next Regular", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(item.nowPlaying ? Color.yellow.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func scrobbleArtwork(_ urlString: String?, nowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    fallbackScrobbleArtwork(nowPlaying: nowPlaying)
                }
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackScrobbleArtwork(nowPlaying: nowPlaying)
        }
    }

    private func fallbackScrobbleArtwork(nowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: nowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(nowPlaying ? .green : .orange)
        }
        .frame(width: 32, height: 32)
    }

    private var filteredScrobbles: [LastfmRecentScrobble] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.latestScrobbles }
        return scrobbleService.latestScrobbles.filter { item in
            item.track.localizedCaseInsensitiveContains(trimmed) ||
            item.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func externalURL(for item: LastfmRecentScrobble) -> URL? {
        if let raw = item.url, let url = URL(string: raw) {
            return url
        }
        let query = "\(item.artist) \(item.track)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://www.last.fm/search/tracks?q=\(query)")
    }

    private func openSearchTag(_ item: LastfmRecentScrobble) {
        if let canonical = canonicalTrackTagsURL(artist: item.artist, track: item.track) {
            openURL(canonical)
            return
        }
        var components = URLComponents(string: "https://www.last.fm/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: "\(item.artist) \(item.track)")
        ]
        if let fallback = components?.url {
            openURL(fallback)
        }
    }

    private func canonicalTrackTagsURL(artist: String, track: String) -> URL? {
        let encodePathComponent: (String) -> String? = { value in
            var allowed = CharacterSet.urlPathAllowed
            allowed.remove(charactersIn: "/")
            return value.addingPercentEncoding(withAllowedCharacters: allowed)
        }
        guard
            let artistPath = encodePathComponent(artist),
            let trackPath = encodePathComponent(track)
        else {
            return nil
        }
        return URL(string: "https://www.last.fm/music/\(artistPath)/_/\(trackPath)/+tags")
    }
}

private struct ScrobbleDetailPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let item: LastfmRecentScrobble

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Track Detail")
                    .font(.custom("Avenir Next Demi Bold", size: 24))
                Spacer()
                Text(scrobbleService.inspectStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.track)
                        .font(.custom("Avenir Next Demi Bold", size: 26))
                    Text("by \(item.artist)")
                        .font(.custom("Avenir Next Medium", size: 20))
                    if let album = scrobbleService.inspectedTrackDetails?.album {
                        Text("from \(album)")
                            .font(.custom("Avenir Next Medium", size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            if let track = scrobbleService.inspectedTrackDetails {
                HStack(spacing: 18) {
                    stat("Listeners", track.listeners)
                    stat("Plays", track.playcount)
                    stat("In your library", track.userPlaycount)
                }
                if !track.tags.isEmpty {
                    Text("Popular tags: \(track.tags.prefix(7).joined(separator: " · "))")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
            }

            if let artist = scrobbleService.inspectedArtistDetails {
                Divider()
                Text(artist.name)
                    .font(.custom("Avenir Next Demi Bold", size: 32))
                HStack(alignment: .top, spacing: 12) {
                    artistArt(artist.imageURL)
                    Text(artist.summary ?? "No artist biography available.")
                        .font(.custom("Avenir Next Regular", size: 14))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 18) {
                    stat("Listeners", artist.listeners)
                    stat("Plays", artist.playcount)
                    stat("In your library", artist.userPlaycount)
                }
                if !artist.tags.isEmpty {
                    Text("Tags: \(artist.tags.prefix(10).joined(separator: " · "))")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                if !artist.similarArtists.isEmpty {
                    Text("Similar Artists")
                        .font(.custom("Avenir Next Medium", size: 17))
                    HStack(spacing: 16) {
                        ForEach(artist.similarArtists.prefix(4)) { similar in
                            VStack(alignment: .leading, spacing: 4) {
                                artistArt(similar.imageURL, size: 74)
                                Text(similar.name)
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let urlString = scrobbleService.inspectedTrackDetails?.imageURL ?? item.imageURL,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: 180, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: 180, height: 180)
        }
    }

    @ViewBuilder
    private func artistArt(_ urlString: String?, size: CGFloat = 180) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Color.white.opacity(0.06)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { $0.formatted() } ?? "—")
                .font(.custom("Avenir Next Demi Bold", size: 22))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ReportsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var period: ReportPeriod = .week
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reports")
                    .font(.custom("Avenir Next Demi Bold", size: 24))

                Picker("Period", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(currentCount.formatted()) Scrobbles")
                        .font(.custom("Avenir Next Demi Bold", size: 34))
                    Text("vs. \(comparisonCount.formatted()) \(comparisonTitle)")
                        .font(.custom("Avenir Next Medium", size: 20))
                    Text("\(periodTitle) trend: \(trendPercentString)")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avg. scrobbles per day")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    reportBar("This \(periodTitle)", value: currentAvg, max: max(currentAvg, comparisonAvg))
                    reportBar(period.previousLabel, value: comparisonAvg, max: max(currentAvg, comparisonAvg))
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top tags")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    if topTags.isEmpty {
                        Text("No tags available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topTags.prefix(5), id: \.name) { tag in
                            reportBar(tag.name, value: tag.count, max: topTags.first?.count ?? 1)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Listening clock")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("You scrobbled the most at \(peakHourLabel) this period.")
                        .font(.custom("Avenir Next Medium", size: 14))
                        .foregroundStyle(.secondary)
                    ListeningClockView(
                        thisWeek: hourlyCountsCurrent,
                        comparison: hourlyCountsComparison,
                        accent: accent
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mainstream score")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("With a \(mainstreamScore)% mainstream score, you are \(mainstreamTone) compared to your recent baseline.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                    reportBar("Mainstream", value: mainstreamScore, max: 100)
                    Text("vs. \(mainstreamBaseline)% baseline")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trends vs. \(comparisonTitle)")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    ForEach(weekdayTrends, id: \.day) { point in
                        HStack {
                            Text(point.day)
                                .font(.custom("Avenir Next Medium", size: 13))
                                .frame(width: 42, alignment: .leading)
                            reportBarInline(value: point.current, max: weekdayMax)
                            Text(point.current.formatted())
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                            Text("vs \(point.previous.formatted())")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func reportBar(_ label: String, value: Int, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.custom("Avenir Next Medium", size: 15))
                Spacer()
                Text(value.formatted())
                    .font(.custom("Avenir Next Medium", size: 15))
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            GeometryReader { geo in
                                let ratio = max > 0 ? Double(value) / Double(max) : 0
                                Rectangle().frame(width: geo.size.width * ratio)
                            }
                        )
                }
                .frame(height: 12)
        }
    }

    private var currentCount: Int {
        let direct = countScrobbles(in: rangeCurrent)
        if direct > 0 { return direct }
        // If local recent history is too shallow, fall back to period top-artist aggregates.
        return topArtistAggregate(for: period)
    }

    private var comparisonCount: Int {
        let direct = countScrobbles(in: rangeComparison)
        if direct > 0 { return direct }
        return 0
    }

    private var currentAvg: Int {
        currentCount / max(1, period.days)
    }

    private var comparisonAvg: Int {
        comparisonCount / max(1, period.days)
    }

    private var trendPercentString: String {
        guard comparisonCount > 0 else { return "Not enough historical data" }
        let delta = Double(currentCount - comparisonCount) / Double(comparisonCount)
        let pct = Int((delta * 100).rounded())
        return pct >= 0 ? "+\(pct)%" : "\(pct)%"
    }

    private func countScrobbles(in range: DateInterval) -> Int {
        return scrobbleService.latestScrobbles.filter { item in
            guard let played = item.playedAt else { return false }
            return range.contains(played)
        }.count
    }

    private var topTags: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for artist in topArtistsForPeriod(period).prefix(12) {
            let name = artist.name.lowercased()
            counts[name, default: 0] += max(1, artist.playcount ?? 0)
        }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private var rangeCurrent: DateInterval {
        period.interval(offsetUnits: 0)
    }

    private var rangeComparison: DateInterval {
        period.interval(offsetUnits: 1)
    }

    private var comparisonTitle: String {
        period.previousLabel
    }

    private var periodTitle: String {
        period.currentLabel
    }

    private func topArtistsForPeriod(_ period: ReportPeriod) -> [LastfmTopArtist] {
        switch period {
        case .week:
            return scrobbleService.weeklyTopArtists
        case .month:
            return scrobbleService.monthlyTopArtists
        case .year:
            return scrobbleService.yearlyTopArtists
        }
    }

    private func topArtistAggregate(for period: ReportPeriod) -> Int {
        topArtistsForPeriod(period).reduce(0) { $0 + max(0, $1.playcount ?? 0) }
    }

    private var hourlyCountsCurrent: [Int] {
        hourCounts(in: rangeCurrent)
    }

    private var hourlyCountsComparison: [Int] {
        hourCounts(in: rangeComparison)
    }

    private func hourCounts(in range: DateInterval) -> [Int] {
        var bins = Array(repeating: 0, count: 24)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt, range.contains(played) else { continue }
            let hour = Calendar.current.component(.hour, from: played)
            bins[hour] += 1
        }
        return bins
    }

    private var peakHourLabel: String {
        let counts = hourlyCountsCurrent
        guard let max = counts.max(), max > 0, let idx = counts.firstIndex(of: max) else { return "00:00" }
        return String(format: "%02d:00", idx)
    }

    private var mainstreamScore: Int {
        switch period {
        case .week:
            let weeklyScore = mainstreamScore(from: scrobbleService.weeklyTopArtists)
            if weeklyScore > 0 {
                return weeklyScore
            }
            return mainstreamScore(in: rangeCurrent)
        case .month:
            let monthlyScore = mainstreamScore(from: scrobbleService.monthlyTopArtists)
            if monthlyScore > 0 {
                return monthlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        case .year:
            let yearlyScore = mainstreamScore(from: scrobbleService.yearlyTopArtists)
            if yearlyScore > 0 {
                return yearlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        }
    }

    private var mainstreamBaseline: Int {
        let baseline: Int
        switch period {
        case .week:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        case .month:
            baseline = mainstreamScore(from: scrobbleService.yearlyTopArtists)
        case .year:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        }
        if baseline > 0 {
            return baseline
        }
        let previous = mainstreamScore(in: rangeComparison)
        return previous > 0 ? previous : max(0, min(100, mainstreamScore - 6))
    }

    private var mainstreamTone: String {
        if mainstreamScore >= 55 { return "more mainstream" }
        if mainstreamScore <= 25 { return "more adventurous" }
        return "balanced"
    }

    private var mainstreamReferenceArtists: Set<String> {
        let global = Set(scrobbleService.globalTopArtistNames.map { $0.lowercased() })
        if !global.isEmpty {
            return global
        }
        return [
            "drake", "taylor swift", "the weeknd", "billie eilish",
            "bad bunny", "dua lipa", "ariana grande", "coldplay",
            "radiohead", "pink floyd"
        ]
    }

    private var mainstreamRankByArtist: [String: Int] {
        var map: [String: Int] = [:]
        for (index, artist) in scrobbleService.globalTopArtistNames.enumerated() {
            map[artist.lowercased()] = index + 1
        }
        return map
    }

    private func mainstreamScore(from artists: [LastfmTopArtist]) -> Int {
        let rankedArtists = artists.filter { !$0.name.isEmpty }
        guard !rankedArtists.isEmpty else { return 0 }

        let weighted = rankedArtists.map { (name: $0.name.lowercased(), weight: max(1, $0.playcount ?? 1)) }
        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }

        let rank = mainstreamRankByArtist
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let score = weighted.reduce(0.0) { partial, item in
                let popularity: Double
                if let artistRank = rank[item.name] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(item.weight) * popularity
            }
            return Int((score / Double(totalWeight) * 100).rounded())
        }

        let mainstreamWeight = weighted
            .filter { mainstreamReferenceArtists.contains($0.name) }
            .reduce(0) { $0 + $1.weight }
        return Int((Double(mainstreamWeight) / Double(totalWeight) * 100).rounded())
    }

    private func mainstreamScore(in range: DateInterval) -> Int {
        var counts: [String: Int] = [:]
        for item in scrobbleService.latestScrobbles {
            guard let playedAt = item.playedAt, range.contains(playedAt) else { continue }
            counts[item.artist.lowercased(), default: 0] += 1
        }
        guard !counts.isEmpty else { return 0 }

        let rank = mainstreamRankByArtist
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let weightedScore = counts.reduce(0.0) { partial, entry in
                let popularity: Double
                if let artistRank = rank[entry.key] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(entry.value) * popularity
            }
            return Int((weightedScore / Double(total) * 100).rounded())
        }

        let mainstreamHits = counts.reduce(0) { partial, entry in
            mainstreamReferenceArtists.contains(entry.key) ? partial + entry.value : partial
        }
        return Int((Double(mainstreamHits) / Double(total) * 100).rounded())
    }

    private var weekdayTrends: [(day: String, current: Int, previous: Int)] {
        let symbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        var current = Array(repeating: 0, count: 7)
        var previous = Array(repeating: 0, count: 7)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt else { continue }
            let weekday = Calendar.current.component(.weekday, from: played)
            let idx = (weekday + 5) % 7
            if rangeCurrent.contains(played) {
                current[idx] += 1
            } else if rangeComparison.contains(played) {
                previous[idx] += 1
            }
        }
        return symbols.indices.map { (symbols[$0], current[$0], previous[$0]) }
    }

    private var weekdayMax: Int {
        max(1, weekdayTrends.map { max($0.current, $0.previous) }.max() ?? 1)
    }

    private func reportBarInline(value: Int, max: Int) -> some View {
        let ratio = max > 0 ? Double(value) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 10)
    }
}

private enum ReportPeriod: CaseIterable {
    case week
    case month
    case year

    var label: String {
        switch self {
        case .week: return "Last.week"
        case .month: return "Last.month"
        case .year: return "Last.year"
        }
    }

    var currentLabel: String {
        switch self {
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    var previousLabel: String {
        switch self {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    func interval(offsetUnits: Int) -> DateInterval {
        let now = Date()
        let days = self.days
        let end = Calendar.current.date(byAdding: .day, value: -(offsetUnits * days), to: now) ?? now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? now
        return DateInterval(start: start, end: end)
    }
}

private struct ListeningClockView: View {
    let thisWeek: [Int]
    let comparison: [Int]
    let accent: Color
    private let comparisonColor = Color.white.opacity(0.2)

    var body: some View {
        GeometryReader { proxy in
            let chartSize = min(proxy.size.width, 320)
            VStack(spacing: 12) {
                ZStack {
                    ForEach(0..<24, id: \.self) { hour in
                        let start = angle(for: hour, offsetDegrees: 0.8)
                        let end = angle(for: hour + 1, offsetDegrees: -0.8)
                        let current = normalized(value(for: hour, in: thisWeek))
                        let previous = normalized(value(for: hour, in: comparison))

                        ClockWedge(startAngle: start, endAngle: end, innerRatio: 0.30, outerRatio: 0.82)
                            .fill(Color.white.opacity(0.05))

                        if previous > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + previous * 0.50
                            )
                            .fill(comparisonColor)
                        }

                        if current > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + current * 0.50
                            )
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.95), accent.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }

                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)

                    Group {
                        clockLabel("00", x: 0, y: -chartSize * 0.42)
                        clockLabel("06", x: chartSize * 0.42, y: 0)
                        clockLabel("12", x: 0, y: chartSize * 0.42)
                        clockLabel("18", x: -chartSize * 0.42, y: 0)
                    }
                }
                .frame(width: chartSize, height: chartSize)
                .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    legendSwatch(color: accent, label: "Current")
                    legendSwatch(color: comparisonColor, label: "Comparison")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 356)
    }

    private func value(for hour: Int, in source: [Int]) -> Int {
        source.indices.contains(hour) ? source[hour] : 0
    }

    private func normalized(_ value: Int) -> CGFloat {
        let peak = max(1, (thisWeek + comparison).max() ?? 1)
        return CGFloat(Double(value) / Double(peak))
    }

    private func angle(for hour: Int, offsetDegrees: Double) -> Angle {
        Angle.degrees((Double(hour % 24) / 24.0) * 360.0 - 90.0 + offsetDegrees)
    }

    private func clockLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.custom("Avenir Next Medium", size: 11))
            .foregroundStyle(.secondary)
            .offset(x: x, y: y)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 10)
            Text(label)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ClockWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat
    let outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let inner = radius * min(max(innerRatio, 0.0), 0.98)
        let outer = radius * min(max(outerRatio, innerRatio), 1.0)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct ChartsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let onOpenTrack: (_ track: String, _ artist: String) -> Void
    let onOpenArtist: (_ artist: String) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Charts")
                    .font(.custom("Avenir Next Demi Bold", size: 24))

                if !scrobbleService.weeklyTopArtists.isEmpty {
                    Text("\(scrobbleService.weeklyTopArtists.count) Artists")
                        .font(.custom("Avenir Next Demi Bold", size: 30))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(scrobbleService.weeklyTopArtists.prefix(8)) { artist in
                                VStack(alignment: .leading, spacing: 6) {
                                    cover(
                                        artist.imageURL,
                                        size: 156,
                                        placeholder: artist.name
                                    )
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: 16))
                                        .lineLimit(1)
                                    Text("\((artist.playcount ?? 0).formatted()) scrobbles")
                                        .font(.custom("Avenir Next Regular", size: 14))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 160)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenArtist(artist.name)
                                }
                            }
                        }
                    }
                    .appPanelStyle()
                }

                Text("\(topAlbums.count) Albums")
                    .font(.custom("Avenir Next Demi Bold", size: 30))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(topAlbums.prefix(8), id: \.id) { album in
                            VStack(alignment: .leading, spacing: 6) {
                                cover(album.imageURL, size: 156)
                                Text(album.title)
                                    .font(.custom("Avenir Next Medium", size: 16))
                                    .lineLimit(1)
                                Text(album.artist)
                                    .font(.custom("Avenir Next Regular", size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Text("\(album.count.formatted()) scrobbles")
                                    .font(.custom("Avenir Next Regular", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 160)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenArtist(album.artist)
                            }
                        }
                    }
                }
                .appPanelStyle()

                Text("\(topTracks.count) Tracks")
                    .font(.custom("Avenir Next Demi Bold", size: 30))
                VStack(spacing: 10) {
                    ForEach(topTracks.prefix(10), id: \.id) { track in
                        HStack(spacing: 10) {
                            cover(track.imageURL, size: 54)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.custom("Avenir Next Medium", size: 18))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.custom("Avenir Next Regular", size: 16))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(track.count.formatted())")
                                .font(.custom("Avenir Next Medium", size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onOpenTrack(track.title, track.artist)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func cover(_ urlString: String?, size: CGFloat, placeholder: String? = nil) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    coverPlaceholder(size: size, text: placeholder)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            coverPlaceholder(size: size, text: placeholder)
        }
    }

    private func coverPlaceholder(size: CGFloat, text: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let text, !text.isEmpty {
                Text(monogram(for: text))
                    .font(.custom("Avenir Next Demi Bold", size: max(18, size * 0.26)))
                    .foregroundStyle(Color.white.opacity(0.78))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: max(14, size * 0.2), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func monogram(for text: String) -> String {
        let parts = text.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map { String($0).uppercased() }
        if !chars.isEmpty {
            return chars.joined()
        }
        return String(text.prefix(2)).uppercased()
    }

    private var topTracks: [ChartEntry] {
        groupedEntries { item in
            (title: item.track, artist: item.artist, imageURL: item.imageURL)
        }
    }

    private var topAlbums: [ChartEntry] {
        groupedEntries { item in
            let title = item.album ?? "Unknown Album"
            return (title: title, artist: item.artist, imageURL: item.imageURL)
        }
    }

    private func groupedEntries(
        _ key: (LastfmRecentScrobble) -> (title: String, artist: String, imageURL: String?)
    ) -> [ChartEntry] {
        var map: [String: ChartEntry] = [:]
        for item in scrobbleService.latestScrobbles {
            let parts = key(item)
            let id = "\(parts.artist)|\(parts.title)"
            if var existing = map[id] {
                existing.count += 1
                if existing.imageURL == nil { existing.imageURL = parts.imageURL }
                map[id] = existing
            } else {
                map[id] = ChartEntry(
                    id: id,
                    title: parts.title,
                    artist: parts.artist,
                    imageURL: parts.imageURL,
                    count: 1
                )
            }
        }
        return map.values.sorted { $0.count > $1.count }
    }
}

private struct ChartEntry {
    let id: String
    let title: String
    let artist: String
    var imageURL: String?
    var count: Int
}

private struct FriendsView: View {
    private enum ActivityFilter: String, CaseIterable, Identifiable {
        case nowPlaying = "Now Playing"
        case hybrid = "Hybrid"
        case all = "All"

        var id: String { rawValue }
    }

    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var query: String
    let onOpenFriendTrack: (LastfmFriendListening) -> Void
    let onOpenGraph: (LastfmFriendListening) -> Void
    @State private var activityFilter: ActivityFilter = .hybrid
    private let recentNowPlayingWindow: TimeInterval = 30 * 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Friends Listening Now")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshFriends() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter friends", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.friendsStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Picker("Activity", selection: $activityFilter) {
                    ForEach(ActivityFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                Text("Showing \(filteredFriends.count) of \(scrobbleService.friendsListening.count) friends")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredFriends.isEmpty {
                    Text("No friend activity available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if activityFilter == .hybrid {
                            sectionHeader("Now Playing", count: nowPlayingFriends.count)
                            ForEach(nowPlayingFriends) { friend in
                                friendRow(friend)
                            }

                            sectionHeader("Recently Active", count: recentFriends.count)
                            ForEach(recentFriends) { friend in
                                friendRow(friend)
                            }
                        } else {
                            ForEach(filteredFriends) { friend in
                                friendRow(friend)
                            }
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func time(_ value: Date?) -> String {
        value?.formatted(date: .omitted, time: .shortened) ?? "-"
    }

    @ViewBuilder
    private func friendAvatar(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    fallbackFriendAvatar(isNowPlaying: isNowPlaying)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            fallbackFriendAvatar(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendAvatar(isNowPlaying: Bool) -> some View {
        Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(isNowPlaying ? .green : .orange)
            .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func friendTrackArtwork(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
                }
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendTrackArtwork(isNowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(isNowPlaying ? .green : .secondary)
                .font(.system(size: 11))
        }
        .frame(width: 26, height: 26)
    }

    private var filteredFriends: [LastfmFriendListening] {
        let activityFiltered: [LastfmFriendListening]
        switch activityFilter {
        case .nowPlaying:
            activityFiltered = scrobbleService.friendsListening.filter(isNowPlaying)
        case .hybrid:
            let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
            activityFiltered = scrobbleService.friendsListening.filter { friend in
                isNowPlaying(friend) || (friend.playedAt ?? .distantPast) >= cutoff
            }
        case .all:
            activityFiltered = scrobbleService.friendsListening
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activityFiltered }
        return activityFiltered.filter { friend in
            friend.user.localizedCaseInsensitiveContains(trimmed) ||
            (friend.track?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (friend.artist?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var nowPlayingFriends: [LastfmFriendListening] {
        filteredFriends.filter(isNowPlaying)
    }

    private var recentFriends: [LastfmFriendListening] {
        filteredFriends.filter { !isNowPlaying($0) }
    }

    private func isNowPlaying(_ friend: LastfmFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        guard let playedAt = friend.playedAt else {
            return false
        }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= recentNowPlayingWindow
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            Text("\(count)")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func friendRow(_ friend: LastfmFriendListening) -> some View {
        let nowPlaying = isNowPlaying(friend)
        return HStack(spacing: 10) {
            friendAvatar(friend.avatarURL, isNowPlaying: nowPlaying)
            friendTrackArtwork(friend.imageURL, isNowPlaying: nowPlaying)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = friendBadgeType(friend) {
                        badgeView(badge, fontSize: 9, horizontal: 6, vertical: 2)
                    }
                }
                Text(friend.country ?? "Unknown location")
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
                if let track = friend.track, let artist = friend.artist {
                    Text("\(track) - \(artist)")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.primary)
                } else {
                    Text("No current track")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onOpenGraph(friend)
            } label: {
                separationChip(for: friend.user)
            }
            .buttonStyle(.plain)
            Text(nowPlaying ? "Now" : time(friend.playedAt))
                .font(.custom("Avenir Next Regular", size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .padding(8)
        .background(nowPlaying ? Color.yellow.opacity(0.24) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpenFriendTrack(friend)
        }
    }

    private func friendBadgeType(_ friend: LastfmFriendListening) -> String? {
        if let raw = friend.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return friend.isSubscriber ? "subscriber" : nil
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = normalized == "alum" ? "ALUM" : "LAST.FM PRO"
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct NeighboursView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenGraph: (LastfmNeighbour) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Neighbours")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshNeighbours() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter neighbours", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.neighboursStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredNeighbours.isEmpty {
                    Text("No neighbours available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    Text("Showing \(filteredNeighbours.count) of \(scrobbleService.neighbours.count) neighbours")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)

                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredNeighbours) { neighbour in
                            neighbourRow(neighbour)
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private var filteredNeighbours: [LastfmNeighbour] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.neighbours }
        return scrobbleService.neighbours.filter { item in
            item.user.localizedCaseInsensitiveContains(trimmed) ||
            (item.realname?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (item.country?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func neighbourRow(_ neighbour: LastfmNeighbour) -> some View {
        HStack(spacing: 10) {
            Button {
                onOpenGraph(neighbour)
            } label: {
                avatar(neighbour.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(neighbour.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = badgeType(neighbour) {
                        badgeView(badge)
                    }
                }
                if let realname = neighbour.realname, !realname.isEmpty {
                    Text(realname)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                } else if let country = neighbour.country, !country.isEmpty {
                    Text(country)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Compatibility")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.secondary)
                    Text(matchLabel(neighbour.matchScore))
                        .font(.custom("Avenir Next Medium", size: 11))
                }
                matchBar(neighbour.matchScore)
            }
            Spacer()
            Button {
                onOpenGraph(neighbour)
            } label: {
                separationChip(for: neighbour.user)
            }
            .buttonStyle(.plain)
            Button {
                if let raw = neighbour.profileURL, let url = URL(string: raw) {
                    openURL(url)
                } else if let url = URL(string: "https://www.last.fm/user/\(neighbour.user)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func avatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    fallbackAvatar()
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackAvatar()
        }
    }

    private func fallbackAvatar() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private func matchLabel(_ score: Double?) -> String {
        guard let score else { return "-" }
        return "\(Int((score * 100).rounded()))%"
    }

    private func matchBar(_ score: Double?) -> some View {
        let ratio = min(1, max(0, score ?? 0))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 8)
            .frame(width: 180)
    }

    private func badgeType(_ neighbour: LastfmNeighbour) -> String? {
        if let raw = neighbour.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return neighbour.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String) -> some View {
        let normalized = type.lowercased()
        let label = normalized == "alum" ? "ALUM" : "LAST.FM PRO"
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)
        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct InteractiveSeparationGraphView: View {
    let graph: SocialGraphSnapshot
    let onOpenUser: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Separation Network")
                    .font(.custom("Avenir Next Demi Bold", size: 18))
                Spacer()
                Text("Pinch to zoom, drag to pan")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        zoom = 1
                        accumulatedZoom = 1
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 11))
            }

            GeometryReader { geo in
                let positions = layoutPositions(in: geo.size)
                ZStack {
                    ForEach(graph.edges) { edge in
                        if let from = positions[edge.from], let to = positions[edge.to] {
                            Path { path in
                                path.move(to: from)
                                path.addLine(to: to)
                            }
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenUser(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSource ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSource || node.isTarget || node.degree <= 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 14)
                            }
                        }
                    }
                }
                .scaleEffect(zoom)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: accumulatedOffset.width + value.translation.width,
                                height: accumulatedOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            accumulatedOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(4.0, max(0.55, accumulatedZoom * value))
                        }
                        .onEnded { _ in
                            accumulatedZoom = zoom
                        }
                )
            }

            HStack(spacing: 14) {
                legendDot(accent, "You")
                legendDot(.cyan, "Target")
                legendDot(.white.opacity(0.6), "Intermediate")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDegree = max(1, graph.nodes.map(\.degree).max() ?? 1)
        let baseRadius = min(size.width, size.height) * 0.44
        let ringStep = baseRadius / CGFloat(maxDegree)
        let groups = Dictionary(grouping: graph.nodes, by: \.degree)
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(graph.nodes.count)

        for degree in groups.keys.sorted() {
            guard let nodesAtDegree = groups[degree] else { continue }
            if degree == 0 {
                if let source = nodesAtDegree.first {
                    positions[source.id] = center
                }
                continue
            }
            let radius = ringStep * CGFloat(degree)
            let count = nodesAtDegree.count
            for (idx, node) in nodesAtDegree.enumerated() {
                let angle = (2 * Double.pi * (Double(idx) / Double(max(1, count)))) - Double.pi / 2
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    private func nodeColor(_ node: SocialGraphNode) -> Color {
        if node.isSource { return accent }
        if node.isTarget { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: SocialGraphNode) -> CGFloat {
        if node.isSource { return 12 }
        if node.isTarget { return 10 }
        return 8
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

private struct AnimatedAvatarImage: NSViewRepresentable {
    let urls: [URL]
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(urls: urls, into: webView)
    }

    final class Coordinator {
        private var lastMarkup: String?

        func load(urls: [URL], into webView: WKWebView) {
            let candidates = urls.map(\.absoluteString)
            guard let data = try? JSONSerialization.data(withJSONObject: candidates),
                  let json = String(data: data, encoding: .utf8) else { return }

            // Use HTML img object-fit cover so avatar is cropped like native cover mode,
            // while still preserving GIF animation.
            let markup = """
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                  html,body{margin:0;padding:0;overflow:hidden;background:transparent;width:100%;height:100%;}
                  #avatar{width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;}
                </style>
              </head>
              <body>
                <img id="avatar" alt="" />
                <script>
                  const urls = \(json);
                  let i = 0;
                  const img = document.getElementById('avatar');
                  function next() {
                    if (i >= urls.length) return;
                    img.src = urls[i++];
                  }
                  img.onerror = next;
                  next();
                </script>
              </body>
            </html>
            """

            guard markup != lastMarkup else { return }
            lastMarkup = markup
            webView.loadHTMLString(markup, baseURL: nil)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.custom("Avenir Next Medium", size: 20))
            }
            Spacer()
        }
        .padding(12)
        .appPanelStyle()
    }
}

private struct AppBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.10, green: 0.13, blue: 0.18), Color(red: 0.05, green: 0.06, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.orange.opacity(0.18))
                .frame(width: 420, height: 420)
                .offset(x: -240, y: -260)
                .blur(radius: 2)

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 360, height: 360)
                .offset(x: 300, y: -180)
                .blur(radius: 6)
        }
    }
}

private extension View {
    func appPanelStyle() -> some View {
        self
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
