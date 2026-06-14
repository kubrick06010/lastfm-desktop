import SwiftUI
enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
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

struct DeepLinkTarget: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case track
        case artist
        case album
    }

    let id: String
    let scrobble: LastfmRecentScrobble
    let kind: Kind
}

private struct SocialGraphTarget: Identifiable, Equatable {
    let id: String
    let user: String
    let profileURL: String?
}



struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @AppStorage("onboarding.firstRunCompleted") private var firstRunOnboardingCompleted = false
    @AppStorage("ui.detailInspectorWidth") private var detailInspectorWidth = 560.0
    @AppStorage("ui.socialInspectorWidth") private var socialInspectorWidth = 860.0
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
    @State private var isOnboardingPresented = false

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
                    .background(appBarBackground)

                GeometryReader { proxy in
                    let availableWidth = proxy.size.width
                    let resolvedDetailWidth = clampedInspectorWidth(
                        preferred: detailInspectorWidth,
                        availableWidth: availableWidth,
                        minimum: 500,
                        maximumRatio: 0.46,
                        hardCap: 860
                    )
                    let resolvedSocialWidth = clampedInspectorWidth(
                        preferred: socialInspectorWidth,
                        availableWidth: availableWidth,
                        minimum: 720,
                        maximumRatio: 0.68,
                        hardCap: 1180
                    )

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
                                },
                                onOpenAlbum: { album, artist, imageURL in
                                    openAlbumDeepLink(album: album, artist: artist, imageURL: imageURL)
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
                            appModalScrim
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        self.deepLinkTarget = nil
                                        scrobbleService.clearInspection()
                                    }
                                }

                            HStack(spacing: 0) {
                                Spacer()
                                InspectorResizeHandle(
                                    width: $detailInspectorWidth,
                                    minimum: 500,
                                    maximum: min(860, availableWidth * 0.46)
                                )
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

                                        // Pass the resolved inspector width down so the detail panel
                                        // can reflow against the real container size instead of using
                                        // a GeometryReader inside a ScrollView, which over-reports width
                                        // and leads to unreadable two-column layouts on narrower windows.
                                        ScrobbleDetailPanel(
                                            item: deepLinkTarget.scrobble,
                                            kind: deepLinkTarget.kind,
                                            availableWidth: resolvedDetailWidth - 32
                                        )
                                        .appPanelStyle()
                                    }
                                    .padding(16)
                                }
                                .frame(width: resolvedDetailWidth)
                                .background(appSidebarBackground)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(appDividerColor).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                            .animation(.easeInOut(duration: 0.22), value: deepLinkTarget.id)
                        }

                        if let socialGraphTarget {
                            appModalScrim
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        self.socialGraphTarget = nil
                                        self.selectedProfileURL = nil
                                    }
                                }

                            HStack(spacing: 0) {
                                Spacer()
                                InspectorResizeHandle(
                                    width: $socialInspectorWidth,
                                    minimum: 720,
                                    maximum: min(1180, availableWidth * 0.68)
                                )
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
                                .frame(width: resolvedSocialWidth, height: min(max(760, proxy.size.height - 24), 980))
                                .background(appSidebarBackground)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(appDividerColor).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                            .animation(.easeInOut(duration: 0.22), value: socialGraphTarget.id)
                        }
                    }
                }

                VStack(spacing: 0) {
                    settingsFooter
                        .background(appBarBackground)

                    BottomTabShell(selectedTab: Binding(
                        get: { selectedTab ?? .scrobbles },
                        set: { selectedTab = $0 }
                    ))
                }
            }
        }
        .onAppear {
            refreshOnboardingPresentation()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.showDiagnostics)) { _ in
            isDiagnosticsPresented = true
        }
        .onChange(of: selectedTab) { newValue in
            guard newValue == .scrobbles else { return }
            Task {
                await scrobbleService.refreshScrobbles()
            }
        }
        .onChange(of: firstRunOnboardingCompleted) { _ in
            refreshOnboardingPresentation()
        }
        .onChange(of: scrobbleService.isAuthenticated) { _ in
            refreshOnboardingPresentation()
        }
        .onChange(of: scrobbleService.sessionStatus) { _ in
            refreshOnboardingPresentation()
        }
        .sheet(isPresented: $isDiagnosticsPresented) {
            DiagnosticsView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 680, minHeight: 520)
        }
        .sheet(isPresented: $isOnboardingPresented) {
            FirstRunOnboardingView(
                isCompleted: $firstRunOnboardingCompleted,
                onOpenSettings: openSettingsWindow,
                onFinish: refreshOnboardingPresentation
            )
            .environmentObject(scrobbleService)
        }
    }

    private var nowPlayingSubtitle: String {
        if let current = scrobbleService.currentTrack {
            return "\(current.artist) - \(current.title)"
        }
        return "No track playing"
    }

    private var appBarBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.78)
    }

    private var appModalScrim: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12)
    }

    private var appSidebarBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial)
    }

    private var appDividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    private var shouldPresentOnboarding: Bool {
        !firstRunOnboardingCompleted || (!scrobbleService.isAuthenticated && scrobbleService.sessionStatus == "Session invalid")
    }

    private func refreshOnboardingPresentation() {
        isOnboardingPresented = shouldPresentOnboarding
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @ViewBuilder
    private var settingsFooter: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsFooterLabel
            }
            .buttonStyle(.plain)
        } else {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                settingsFooterLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsFooterLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
            Text("\(scrobbleService.profile?.name ?? "Guest") (\(scrobbleService.isAuthenticated ? "Online" : "Offline"))")
                .font(.custom("Avenir Next Medium", size: 14))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func openDeepLink(scrobble: LastfmRecentScrobble) {
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(id: scrobble.id, scrobble: scrobble, kind: .track)
        }
        Task {
            await scrobbleService.inspect(scrobble: scrobble)
        }
    }

    private func openDeepLink(track: String?, artist: String, imageURL: String? = nil) {
        let hasTrack = track?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let title = hasTrack ? track! : artist
        let item = LastfmRecentScrobble(
            id: "deep-\(hasTrack ? "track" : "artist")-\(artist)|\(title)",
            track: title,
            artist: artist,
            album: nil,
            imageURL: imageURL,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false
        )
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(
                id: item.id,
                scrobble: item,
                kind: hasTrack ? .track : .artist
            )
        }
        Task {
            await scrobbleService.inspect(scrobble: item)
        }
    }

    private func openAlbumDeepLink(album: String, artist: String, imageURL: String? = nil) {
        let item = LastfmRecentScrobble(
            id: "deep-album-\(artist)|\(album)",
            track: album,
            artist: artist,
            album: album,
            imageURL: imageURL,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false
        )
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(id: item.id, scrobble: item, kind: .album)
        }
        Task {
            await scrobbleService.inspect(scrobble: item)
        }
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

    private func clampedInspectorWidth(
        preferred: Double,
        availableWidth: CGFloat,
        minimum: CGFloat,
        maximumRatio: CGFloat,
        hardCap: CGFloat
    ) -> CGFloat {
        let maximum = min(hardCap, availableWidth * maximumRatio)
        return min(max(CGFloat(preferred), minimum), maximum)
    }
}
