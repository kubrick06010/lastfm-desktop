import SwiftUI

private enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard = "Dashboard"
    case queue = "Queue"
    case profile = "Profile"
    case scrobbles = "Scrobbles"
    case friends = "Friends"
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
        case .friends:
            return "person.3.sequence"
        case .account:
            return "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var selectedTab: WorkspaceTab? = .dashboard
    @State private var username = ""
    @State private var password = ""
    @State private var friendsQuery = ""
    @State private var scrobblesQuery = ""

    var body: some View {
        NavigationSplitView {
            List(WorkspaceTab.allCases, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.symbol)
                    .tag(tab)
                    .font(.custom("Avenir Next Demi Bold", size: 14))
            }
            .navigationTitle("LastfmModern")
            .listStyle(.sidebar)
        } detail: {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(nowPlayingTitle)
                        .font(.custom("Avenir Next Demi Bold", size: 24))
                    Text(nowPlayingTitle)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.28))

                ZStack {
                    AppBackdrop()
                    switch selectedTab ?? .dashboard {
                    case .dashboard:
                        DashboardView()
                    case .queue:
                        QueueView()
                    case .profile:
                        ProfileView()
                    case .scrobbles:
                        ScrobblesView(query: $scrobblesQuery)
                    case .friends:
                        FriendsView(query: $friendsQuery)
                    case .account:
                        AccountView(username: $username, password: $password)
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                    Text("\(scrobbleService.profile?.name ?? "Guest") (\(scrobbleService.isAuthenticated ? "Online" : "Offline"))")
                        .font(.custom("Avenir Next Medium", size: 14))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.35))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Queue Track") {
                    scrobbleService.queueCurrentTrack()
                }
                Button("Submit Queue") {
                    Task { await scrobbleService.submitQueued() }
                }
                Toggle("Scrobbling", isOn: Binding(
                    get: { scrobbleService.scrobblingEnabled },
                    set: { _ in scrobbleService.toggleScrobbling() }
                ))
                .toggleStyle(.switch)
            }
        }
    }

    private var nowPlayingTitle: String {
        if let current = scrobbleService.currentTrack {
            return "\(current.artist) - \(current.title) - Last.fm Scrobbler"
        }
        return "Last.fm Scrobbler"
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Listening Dashboard")
                    .font(.custom("Avenir Next Heavy", size: 30))
                    .foregroundStyle(.primary)

                NowPlayingView(compact: false)

                if let track = scrobbleService.currentTrackDetails {
                    HStack(alignment: .top, spacing: 12) {
                        dashboardArt(track.imageURL)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.name)
                                .font(.custom("Avenir Next Heavy", size: 24))
                            Text("by \(track.artist)")
                                .font(.custom("Avenir Next Demi Bold", size: 18))
                            if let album = track.album {
                                Text("from \(album)")
                                    .font(.custom("Avenir Next Medium", size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Text("Listeners: \(count(track.listeners)) · Plays: \(count(track.playcount)) · Yours: \(count(track.userPlaycount))")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                            if !track.tags.isEmpty {
                                Text("Tags: \(track.tags.prefix(8).joined(separator: " · "))")
                                    .font(.custom("Avenir Next Medium", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .appPanelStyle()
                }

                if let artist = scrobbleService.currentArtistDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(artist.name)
                            .font(.custom("Avenir Next Heavy", size: 24))
                        Text(artist.summary ?? "No artist description available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .lineLimit(4)
                        if !artist.similarArtists.isEmpty {
                            Text("Similar Artists")
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                            HStack(spacing: 12) {
                                ForEach(artist.similarArtists.prefix(5)) { similar in
                                    VStack(spacing: 3) {
                                        dashboardArt(similar.imageURL, size: 52)
                                        Text(similar.name)
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .appPanelStyle()
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MetricCard(title: "Queued", value: "\(scrobbleService.queuedScrobbles.count)", icon: "shippingbox")
                    MetricCard(title: "Submit Failures", value: "\(scrobbleService.queueSubmitFailures)", icon: "exclamationmark.triangle")
                    MetricCard(title: "Player Events", value: "\(scrobbleService.playerEventCount)", icon: "waveform")
                    MetricCard(
                        title: "Next Retry",
                        value: scrobbleService.nextRetryAt?.formatted(date: .omitted, time: .standard) ?? "None",
                        icon: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                    )
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: scrobbleService.queuedScrobbles.count)

                DiagnosticsPanel()
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

    private func count(_ value: Int?) -> String {
        (value ?? 0).formatted()
    }
}

private struct QueueView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Scrobble Queue")
                    .font(.custom("Avenir Next Heavy", size: 28))
                Spacer()
                Text("\(scrobbleService.queuedScrobbles.count) items")
                    .font(.custom("Avenir Next Demi Bold", size: 13))
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
                                    Text(track.title).font(.custom("Avenir Next Demi Bold", size: 14))
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
                    .font(.custom("Avenir Next Heavy", size: 28))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack {
                        Button("Sign In") {
                            Task { await scrobbleService.signIn(username: username, password: password) }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!scrobbleService.apiConfigured)

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
                }
                .font(.custom("Avenir Next Medium", size: 13))
                .appPanelStyle()

                if let authError = scrobbleService.authError {
                    Text(authError)
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(.red)
                        .padding(10)
                        .appPanelStyle()
                }

                if let apiError = scrobbleService.lastAPIError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(apiError)
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                            .foregroundStyle(.red)
                        if let hint = scrobbleService.lastRecoveryHint {
                            Text(hint)
                                .font(.custom("Avenir Next Regular", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
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
                        .font(.custom("Avenir Next Heavy", size: 28))
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
                            .font(.custom("Avenir Next Demi Bold", size: 14))
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
                            .font(.custom("Avenir Next Demi Bold", size: 14))
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
                                .font(.custom("Avenir Next Demi Bold", size: 12))
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
                        .font(.custom("Avenir Next Heavy", size: 28))
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
                            if scrobbleService.isSubscriber {
                                Text("SUBSCRIBER")
                                    .font(.custom("Avenir Next Demi Bold", size: 9))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.black, in: Capsule())
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name)
                                .font(.custom("Avenir Next Heavy", size: 22))
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
                    .font(.custom("Avenir Next Demi Bold", size: 14))
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
                                        .font(.custom("Avenir Next Demi Bold", size: 13))
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
                        .font(.custom("Avenir Next Demi Bold", size: 14))
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
                .font(.custom("Avenir Next Demi Bold", size: 13))
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
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image.resizable().scaledToFill()
                default:
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
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

    private var weeklyMax: Int {
        scrobbleService.weeklyTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var overallMax: Int {
        scrobbleService.overallTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var profileArtistCount: Int? {
        scrobbleService.profile?.artistCount
    }
}

private struct ScrobblesView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    @State private var selected: LastfmRecentScrobble?

    var body: some View {
        ZStack {
            if let selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                self.selected = nil
                                scrobbleService.clearInspection()
                            }
                        } label: {
                            Label("Back to Scrobbles", systemImage: "chevron.left")
                                .font(.custom("Avenir Next Demi Bold", size: 16))
                        }
                        .buttonStyle(.plain)
                        ScrobbleDetailPanel(item: selected)
                            .appPanelStyle()
                    }
                    .padding(24)
                }
                .transition(.move(edge: .trailing))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Your Scrobbles")
                                .font(.custom("Avenir Next Heavy", size: 28))
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
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredScrobbles.prefix(80)) { item in
                                    HStack(spacing: 10) {
                                        scrobbleArtwork(item.imageURL, nowPlaying: item.nowPlaying)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.track)
                                                .font(.custom("Avenir Next Demi Bold", size: 13))
                                            Text(item.artist)
                                                .font(.custom("Avenir Next Regular", size: 12))
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        HStack(spacing: 10) {
                                            Button {
                                                Task { await scrobbleService.love(scrobble: item) }
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
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            selected = item
                                        }
                                        Task {
                                            await scrobbleService.inspect(track: item.track, artist: item.artist)
                                        }
                                    }
                                }
                            }
                            .appPanelStyle()
                        }
                    }
                    .padding(24)
                }
                .transition(.move(edge: .leading))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selected?.id)
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
        let query = "\(item.artist) \(item.track)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://www.last.fm/search/tags?q=\(query)") {
            openURL(url)
        }
    }
}

private struct ScrobbleDetailPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let item: LastfmRecentScrobble

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Track Detail")
                    .font(.custom("Avenir Next Heavy", size: 24))
                Spacer()
                Text(scrobbleService.inspectStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 12) {
                artwork
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.track)
                        .font(.custom("Avenir Next Heavy", size: 26))
                    Text("by \(item.artist)")
                        .font(.custom("Avenir Next Demi Bold", size: 20))
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
                    .font(.custom("Avenir Next Heavy", size: 32))
                HStack(alignment: .top, spacing: 12) {
                    artistArt(artist.imageURL)
                    Text(artist.summary ?? "No artist biography available.")
                        .font(.custom("Avenir Next Regular", size: 14))
                        .lineLimit(5)
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
                        .font(.custom("Avenir Next Demi Bold", size: 17))
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
            Text((value ?? 0).formatted())
                .font(.custom("Avenir Next Heavy", size: 22))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct FriendsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var query: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Friends Listening Now")
                        .font(.custom("Avenir Next Heavy", size: 28))
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

                if filteredFriends.isEmpty {
                    Text("No friend activity available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredFriends.prefix(80)) { friend in
                            HStack(spacing: 10) {
                                friendAvatar(friend.avatarURL, isNowPlaying: friend.nowPlaying)
                                friendTrackArtwork(friend.imageURL, isNowPlaying: friend.nowPlaying)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        Text(friend.user)
                                            .font(.custom("Avenir Next Demi Bold", size: 13))
                                        if friend.isSubscriber {
                                            Text("Subscriber")
                                                .font(.custom("Avenir Next Demi Bold", size: 10))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(.black, in: Capsule())
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
                                Text(friend.nowPlaying ? "Now" : time(friend.playedAt))
                                    .font(.custom("Avenir Next Regular", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .padding(8)
                            .background(friend.nowPlaying ? Color.yellow.opacity(0.24) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.friendsListening }
        return scrobbleService.friendsListening.filter { friend in
            friend.user.localizedCaseInsensitiveContains(trimmed) ||
            (friend.track?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (friend.artist?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}

private struct DiagnosticsPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Diagnostics")
                .font(.custom("Avenir Next Demi Bold", size: 14))
            diagnosticRow("Monitor", scrobbleService.monitorStatus)
            diagnosticRow("Playback State", scrobbleService.playbackState)
            diagnosticRow("Threshold", "\(Int(scrobbleService.scrobbleThreshold))s")
            diagnosticRow("Elapsed", "\(Int(scrobbleService.elapsedForCurrentTrack))s")
            diagnosticRow("Now Playing Delay", "\(scrobbleService.nowPlayingDelaySeconds)s")
            diagnosticRow("Retry Delay", "\(scrobbleService.retryDelaySeconds)s")
            diagnosticRow("Validation Source", scrobbleService.validationSource)
            if let lastSubmittedAt = scrobbleService.lastSubmittedAt {
                diagnosticRow("Last Submit", lastSubmittedAt.formatted())
            }
            if let nextRetryAt = scrobbleService.nextRetryAt {
                diagnosticRow("Next Retry", nextRetryAt.formatted())
            }
        }
        .appPanelStyle()
    }

    private func diagnosticRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.custom("Avenir Next Medium", size: 12))
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
                    .font(.custom("Avenir Next Heavy", size: 20))
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
