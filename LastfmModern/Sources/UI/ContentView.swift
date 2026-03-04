import SwiftUI

private enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard = "Dashboard"
    case queue = "Queue"
    case profile = "Profile"
    case scrobbles = "Scrobbles"
    case reports = "Reports"
    case charts = "Charts"
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
        case .reports:
            return "chart.pie.fill"
        case .charts:
            return "list.number"
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
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("Last.fm Scrobbler")
                            .font(.custom("Avenir Next Demi Bold", size: 24))
                        Text(nowPlayingSubtitle)
                            .font(.custom("Avenir Next Medium", size: 14))
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
                        DashboardView()
                    case .queue:
                        QueueView()
                    case .profile:
                        ProfileView()
                    case .scrobbles:
                        ScrobblesView(query: $scrobblesQuery)
                    case .reports:
                        ReportsView()
                    case .charts:
                        ChartsView()
                    case .friends:
                        FriendsView(query: $friendsQuery)
                    case .account:
                        AccountView(username: $username, password: $password)
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ScrobbleToolbarControls()
            }
        }
    }

    private var nowPlayingSubtitle: String {
        if let current = scrobbleService.currentTrack {
            return "\(current.artist) - \(current.title)"
        }
        return "No track playing"
    }
}

private struct ScrobbleToolbarControls: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        ViewThatFits(in: .horizontal) {
            toolbarLayoutFull
            toolbarLayoutCompact
            toolbarLayoutMinimal
        }
    }

    private var toolbarLayoutFull: some View {
        HStack(spacing: 10) {
            queueButton(showText: true, controlSize: .regular)
            submitButton(showText: true, controlSize: .regular)
            scrobbleToggle(showLabel: true, compact: false)
        }
    }

    private var toolbarLayoutCompact: some View {
        HStack(spacing: 8) {
            queueButton(showText: false, controlSize: .small)
            submitButton(showText: false, controlSize: .small)
            scrobbleToggle(showLabel: false, compact: true)
        }
    }

    private var toolbarLayoutMinimal: some View {
        HStack(spacing: 6) {
            queueButton(showText: false, controlSize: .mini)
            submitButton(showText: false, controlSize: .mini)
            Toggle("", isOn: Binding(
                get: { scrobbleService.scrobblingEnabled },
                set: { _ in scrobbleService.toggleScrobbling() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help(scrobbleService.scrobblingEnabled ? "Scrobbling enabled" : "Scrobbling disabled")
        }
    }

    private func queueButton(showText: Bool, controlSize: ControlSize) -> some View {
        Button {
            scrobbleService.queueCurrentTrack()
        } label: {
            if showText {
                Label("Queue", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .lineLimit(1)
            } else {
                Image(systemName: "text.line.first.and.arrowtriangle.forward")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .buttonStyle(.bordered)
        .controlSize(controlSize)
        .help("Queue current track")
    }

    private func submitButton(showText: Bool, controlSize: ControlSize) -> some View {
        Button {
            Task { await scrobbleService.submitQueued() }
        } label: {
            if showText {
                Label("Submit", systemImage: "arrow.up.forward.circle.fill")
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .lineLimit(1)
            } else {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .foregroundStyle(.white)
        .controlSize(controlSize)
        .help("Submit queued scrobbles")
    }

    private func scrobbleToggle(showLabel: Bool, compact: Bool) -> some View {
        VStack(spacing: 2) {
            if showLabel {
                Text("Scrobbling")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            Toggle("", isOn: Binding(
                get: { scrobbleService.scrobblingEnabled },
                set: { _ in scrobbleService.toggleScrobbling() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(compact ? .mini : .small)
        }
        .padding(.horizontal, compact ? 6 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .background(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .fill(Color.black.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 10 : 12, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .help(scrobbleService.scrobblingEnabled ? "Scrobbling enabled" : "Scrobbling disabled")
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
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(filteredScrobbles) { item in
                                    HStack(spacing: 10) {
                                        HStack(spacing: 10) {
                                            scrobbleArtwork(item.imageURL, nowPlaying: item.nowPlaying)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.track)
                                                    .font(.custom("Avenir Next Demi Bold", size: 13))
                                                Text(item.artist)
                                                    .font(.custom("Avenir Next Regular", size: 12))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.25)) {
                                                selected = item
                                            }
                                            Task {
                                                await scrobbleService.inspect(scrobble: item)
                                            }
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

private struct ReportsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var period: ReportPeriod = .week
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reports")
                    .font(.custom("Avenir Next Heavy", size: 30))

                Picker("Period", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(thisWeekCount.formatted()) Scrobbles")
                        .font(.custom("Avenir Next Heavy", size: 44))
                    Text("vs. \(lastWeekCount.formatted()) last week")
                        .font(.custom("Avenir Next Demi Bold", size: 24))
                    Text("Week trend: \(trendPercentString)")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avg. scrobbles per day")
                        .font(.custom("Avenir Next Heavy", size: 34))
                    reportBar("This week", value: thisWeekAvg, max: max(thisWeekAvg, lastWeekAvg))
                    reportBar("Last week", value: lastWeekAvg, max: max(thisWeekAvg, lastWeekAvg))
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top tags")
                        .font(.custom("Avenir Next Heavy", size: 34))
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
                        .font(.custom("Avenir Next Heavy", size: 34))
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
                        .font(.custom("Avenir Next Heavy", size: 34))
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
                        .font(.custom("Avenir Next Heavy", size: 34))
                    ForEach(weekdayTrends, id: \.day) { point in
                        HStack {
                            Text(point.day)
                                .font(.custom("Avenir Next Demi Bold", size: 13))
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
                    .font(.custom("Avenir Next Demi Bold", size: 15))
                Spacer()
                Text(value.formatted())
                    .font(.custom("Avenir Next Demi Bold", size: 15))
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

    private var thisWeekCount: Int {
        countScrobbles(in: rangeCurrent)
    }

    private var lastWeekCount: Int {
        countScrobbles(in: rangeComparison)
    }

    private var thisWeekAvg: Int {
        thisWeekCount / max(1, period.days)
    }

    private var lastWeekAvg: Int {
        lastWeekCount / max(1, period.days)
    }

    private var trendPercentString: String {
        guard lastWeekCount > 0 else { return "New activity trend" }
        let delta = Double(thisWeekCount - lastWeekCount) / Double(lastWeekCount)
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
        for artist in scrobbleService.weeklyTopArtists.prefix(12) {
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
        switch period {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
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
        let artists = Set(scrobbleService.latestScrobbles.compactMap { $0.artist.lowercased() })
        guard !artists.isEmpty else { return 0 }
        let common = ["drake", "taylor swift", "the weeknd", "billie eilish", "bad bunny", "dua lipa", "ariana grande", "coldplay", "radiohead", "pink floyd"]
        let mainstreamHits = artists.filter { common.contains($0) }.count
        return Int((Double(mainstreamHits) / Double(artists.count) * 100).rounded())
    }

    private var mainstreamBaseline: Int {
        max(0, min(100, mainstreamScore - 8))
    }

    private var mainstreamTone: String {
        if mainstreamScore >= 55 { return "more mainstream" }
        if mainstreamScore <= 25 { return "more adventurous" }
        return "balanced"
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

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                let start = Angle(degrees: Double(hour) * 15 - 90)
                let end = Angle(degrees: Double(hour + 1) * 15 - 90)
                RingSegment(startAngle: start, endAngle: end, innerRadius: 80, outerRadius: outerRadius(for: hour, source: comparison))
                    .fill(Color.white.opacity(0.10))
                RingSegment(startAngle: start, endAngle: end, innerRadius: 46, outerRadius: outerRadius(for: hour, source: thisWeek))
                    .fill(accent)
            }

            Circle()
                .fill(Color.black.opacity(0.9))
                .frame(width: 86, height: 86)
                .overlay {
                    VStack(spacing: 2) {
                        Text("00")
                            .font(.custom("Avenir Next Demi Bold", size: 16))
                            .foregroundStyle(.secondary)
                        Text("06    12    18")
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .frame(width: 260, height: 260)
    }

    private func outerRadius(for hour: Int, source: [Int]) -> CGFloat {
        let maxValue = max(1, source.max() ?? 1)
        let value = source.indices.contains(hour) ? source[hour] : 0
        let normalized = CGFloat(value) / CGFloat(maxValue)
        return 90 + normalized * 38
    }
}

private struct RingSegment: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRadius: CGFloat
    let outerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var p = Path()
        p.addArc(center: center, radius: outerRadius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        p.addArc(center: center, radius: innerRadius, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

private struct ChartsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Charts")
                    .font(.custom("Avenir Next Heavy", size: 30))

                if !scrobbleService.weeklyTopArtists.isEmpty {
                    Text("\(scrobbleService.weeklyTopArtists.count) Artists")
                        .font(.custom("Avenir Next Heavy", size: 38))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(scrobbleService.weeklyTopArtists.prefix(8)) { artist in
                                VStack(alignment: .leading, spacing: 6) {
                                    cover(artist.imageURL, size: 156)
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Demi Bold", size: 16))
                                        .lineLimit(1)
                                    Text("\((artist.playcount ?? 0).formatted()) scrobbles")
                                        .font(.custom("Avenir Next Regular", size: 14))
                                        .foregroundStyle(.secondary)
                                }
                                .frame(width: 160)
                            }
                        }
                    }
                    .appPanelStyle()
                }

                Text("\(topAlbums.count) Albums")
                    .font(.custom("Avenir Next Heavy", size: 38))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(topAlbums.prefix(8), id: \.id) { album in
                            VStack(alignment: .leading, spacing: 6) {
                                cover(album.imageURL, size: 156)
                                Text(album.title)
                                    .font(.custom("Avenir Next Demi Bold", size: 16))
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
                        }
                    }
                }
                .appPanelStyle()

                Text("\(topTracks.count) Tracks")
                    .font(.custom("Avenir Next Heavy", size: 38))
                VStack(spacing: 10) {
                    ForEach(topTracks.prefix(10), id: \.id) { track in
                        HStack(spacing: 10) {
                            cover(track.imageURL, size: 54)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.custom("Avenir Next Demi Bold", size: 18))
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.custom("Avenir Next Regular", size: 16))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Text("\(track.count.formatted())")
                                .font(.custom("Avenir Next Demi Bold", size: 16))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func cover(_ urlString: String?, size: CGFloat) -> some View {
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
    @State private var activityFilter: ActivityFilter = .hybrid

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
            activityFiltered = scrobbleService.friendsListening.filter(\.nowPlaying)
        case .hybrid:
            let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
            activityFiltered = scrobbleService.friendsListening.filter { friend in
                friend.nowPlaying || (friend.playedAt ?? .distantPast) >= cutoff
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
        filteredFriends.filter(\.nowPlaying)
    }

    private var recentFriends: [LastfmFriendListening] {
        filteredFriends.filter { !$0.nowPlaying }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 12))
            Text("\(count)")
                .font(.custom("Avenir Next Demi Bold", size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func friendRow(_ friend: LastfmFriendListening) -> some View {
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
