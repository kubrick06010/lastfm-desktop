import SwiftUI

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var moodPalette = DashboardMoodPalette.fallback
    let onOpenTrackDetail: (_ track: String, _ artist: String, _ imageURL: String?) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = DashboardMetrics(width: proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    Text("Listening Dashboard")
                        .font(.custom("Avenir Next Medium", size: metrics.screenTitleFont))
                        .foregroundStyle(.primary)

                    if let nowPlaying = scrobbleService.currentTrack {
                        VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                            if metrics.isCompact {
                                VStack(alignment: .leading, spacing: 10) {
                                    sourceLabel(nowPlaying)
                                    dashboardMiniProgress(compact: true)
                                }
                            } else {
                                HStack(alignment: .top) {
                                    sourceLabel(nowPlaying)
                                    Spacer()
                                    dashboardMiniProgress(compact: false)
                                }
                            }

                            Divider().overlay(sectionDividerColor)

                            if metrics.isCompact {
                                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                    dashboardArt(dashboardTrackImageURL, size: metrics.trackArtSize)
                                        .onTapGesture {
                                            openDetailForCurrentTrack(nowPlaying)
                                        }
                                    trackSummary(nowPlaying, metrics: metrics)
                                }
                            } else {
                                HStack(alignment: .top, spacing: metrics.cardSpacing) {
                                    dashboardArt(dashboardTrackImageURL, size: metrics.trackArtSize)
                                        .onTapGesture {
                                            openDetailForCurrentTrack(nowPlaying)
                                        }
                                    trackSummary(nowPlaying, metrics: metrics)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            trackInsightsCard(fontSize: metrics.bodyFont)

                            Divider().overlay(sectionDividerColor)

                            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                Text(scrobbleService.currentArtistDetails?.name ?? nowPlaying.artist)
                                    .font(.custom("Avenir Next Demi Bold", size: metrics.artistTitleFont))

                                if metrics.isCompact {
                                    VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                        dashboardArt(scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL, size: metrics.artistArtSize)
                                        HTMLSummaryText(rawHTML: artistSummaryText, fontSize: metrics.bodyFont, lineLimit: metrics.summaryLineLimit)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: metrics.cardSpacing) {
                                        dashboardArt(scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL, size: metrics.artistArtSize)
                                        HTMLSummaryText(rawHTML: artistSummaryText, fontSize: metrics.bodyFont, lineLimit: metrics.summaryLineLimit)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                statGrid(metrics: metrics)

                                if let tags = scrobbleService.currentArtistDetails?.tags, !tags.isEmpty {
                                    tagLinks(title: "Popular tags", tags: Array(tags.prefix(metrics.maxTagCount)))
                                }

                                if let similar = scrobbleService.currentArtistDetails?.similarArtists, !similar.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Similar Artists")
                                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionTitleFont))
                                        similarArtistsGrid(Array(similar.prefix(metrics.maxSimilarArtists)), metrics: metrics)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .padding(metrics.cardPadding)
                        .background {
                            dashboardBackgroundArt(dashboardHeroImageURL)
                        }
                        .background(dashboardCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(cardBorderColor, lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.45), value: moodPalette)
                    } else {
                        Text("No track detected.")
                            .font(.custom("Avenir Next Medium", size: 14))
                            .foregroundStyle(.secondary)
                            .padding(20)
                            .appPanelStyle()
                    }
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: dashboardMoodKey) {
            let palette = await MoodPaletteEngine.resolvePalette(
                trackTags: scrobbleService.currentTrackDetails?.tags ?? [],
                artistTags: scrobbleService.currentArtistDetails?.tags ?? [],
                artworkURL: dashboardHeroImageURL
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    moodPalette = palette
                }
            }
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
                    placeholderFill
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(placeholderFill)
                .frame(width: size, height: size)
        }
    }

    // The dashboard follows the same responsive rule used in the inspector:
    // reflow before shrink. Modern desktop UI tends to preserve readable type
    // and information hierarchy by changing composition first (stacking,
    // adaptive grids, capped content widths) and only then reducing font size.
    // References:
    // Apple. (n.d.). Human Interface Guidelines. https://developer.apple.com/design/human-interface-guidelines/
    // Apple. (n.d.). ViewThatFits. https://developer.apple.com/documentation/swiftui/viewthatfits
    private struct DashboardMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 960 }
        var isNarrow: Bool { width < 760 }
        var contentMaxWidth: CGFloat { isCompact ? .infinity : 1180 }
        var screenTitleFont: CGFloat { isNarrow ? 20 : 24 }
        var cardPadding: CGFloat { isNarrow ? 18 : 22 }
        var cardSpacing: CGFloat { isNarrow ? 10 : 14 }
        var sectionSpacing: CGFloat { isNarrow ? 16 : 18 }
        var trackArtSize: CGFloat { isNarrow ? 112 : 132 }
        var artistArtSize: CGFloat { isNarrow ? 112 : 126 }
        var titleFont: CGFloat { isNarrow ? 22 : 28 }
        var subtitleFont: CGFloat { isNarrow ? 16 : 18 }
        var bodyFont: CGFloat { isNarrow ? 14 : 15 }
        var artistTitleFont: CGFloat { isNarrow ? 20 : 22 }
        var sectionTitleFont: CGFloat { isNarrow ? 16 : 18 }
        var summaryLineLimit: Int { isNarrow ? 5 : 6 }
        var maxTagCount: Int { isNarrow ? 5 : 6 }
        var maxSimilarArtists: Int { isCompact ? 6 : 8 }
        var statColumns: [GridItem] {
            isCompact
                ? [GridItem(.adaptive(minimum: isNarrow ? 140 : 160), alignment: .leading)]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
        var similarArtistColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 84 : 92), spacing: 18, alignment: .topLeading)]
        }
    }

    private func sourceLabel(_ nowPlaying: Track) -> some View {
        Label {
            Text("Scrobbling from \(nowPlaying.sourceApp ?? "Music")")
                .font(.custom("Avenir Next Medium", size: 15))
        } icon: {
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func trackSummary(_ nowPlaying: Track, metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(scrobbleService.currentTrackDetails?.name ?? nowPlaying.title)
                .font(.custom("Avenir Next Demi Bold", size: metrics.titleFont))
                .lineLimit(metrics.isNarrow ? 4 : 3)
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
                .font(.custom("Avenir Next Demi Bold", size: metrics.subtitleFont))
                .foregroundStyle(.secondary)
                .lineLimit(metrics.isNarrow ? 3 : 2)
            if let album = scrobbleService.currentTrackDetails?.album ?? nowPlaying.album {
                Text("from \(album)")
                    .font(.custom("Avenir Next Medium", size: metrics.bodyFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isNarrow ? 3 : 2)
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
    }

    private func statGrid(metrics: DashboardMetrics) -> some View {
        LazyVGrid(columns: metrics.statColumns, alignment: .leading, spacing: 12) {
            statColumn("Listeners", scrobbleService.currentArtistDetails?.listeners)
            statColumn("Plays", scrobbleService.currentArtistDetails?.playcount)
            statColumn("Plays in your library", scrobbleService.currentTrackDetails?.userPlaycount)
        }
    }

    private func similarArtistsGrid(_ artists: [LastfmSimilarArtist], metrics: DashboardMetrics) -> some View {
        LazyVGrid(columns: metrics.similarArtistColumns, alignment: .leading, spacing: 14) {
            ForEach(artists, id: \.name) { item in
                similarArtistLink(item, compact: metrics.isNarrow)
            }
        }
    }

    @ViewBuilder
    private func dashboardBackgroundArt(_ urlString: String?) -> some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(nsColor: moodPalette.gradientStart),
                        Color(nsColor: moodPalette.gradientEnd)
                    ]
                    : [
                        Color(nsColor: moodPalette.gradientStart).opacity(0.22),
                        Color(nsColor: moodPalette.gradientEnd).opacity(0.14)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 30)
                            .saturation(0.72)
                            .opacity(colorScheme == .dark ? 0.34 : 0.22)
                    default:
                        Color.clear
                    }
                }
            }
            // The mood engine picks a tag-driven palette and then folds dominant
            // artwork color back into it, so the backdrop feels responsive to the
            // current artist without becoming unreadable.
            Circle()
                .fill(Color(nsColor: moodPalette.glowPrimary).opacity(colorScheme == .dark ? 0.22 : 0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: 160, y: -80)
            Circle()
                .fill(Color(nsColor: moodPalette.glowSecondary).opacity(colorScheme == .dark ? 0.18 : 0.14))
                .frame(width: 240, height: 240)
                .blur(radius: 22)
                .offset(x: -180, y: 60)
            Circle()
                .fill(Color(nsColor: moodPalette.accent).opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 20)
                .offset(x: 40, y: 120)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.24), Color.black.opacity(0.52)]
                    : [Color.white.opacity(0.24), Color.white.opacity(0.62)],
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
                    .opacity(colorScheme == .dark ? 0.12 : 0.18),
                in: Capsule()
            )
    }

    private func dashboardMiniProgress(compact: Bool) -> some View {
        VStack(alignment: compact ? .leading : .trailing, spacing: 4) {
            playbackChip
            ProgressView(value: scrobbleService.scrobbleProgress, total: 1)
                .frame(width: compact ? 132 : 90)
                .progressViewStyle(.linear)
            Text("\(Int(scrobbleService.elapsedForCurrentTrack))s / \(Int(scrobbleService.scrobbleThreshold))s")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func trackInsightsCard(fontSize: CGFloat) -> some View {
        // Mirrors the legacy client "you listened X times" callout while gracefully
        // degrading when Last.fm omits user-specific counters.
        Text("You've listened to \(scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist ?? "this artist") \(count(scrobbleService.currentArtistDetails?.userPlaycount)) times and \(scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title ?? "this track") \(count(scrobbleService.currentTrackDetails?.userPlaycount)) time(s).")
            .font(.custom("Avenir Next Medium", size: fontSize))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(calloutBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
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

    private var dashboardMoodKey: String {
        [
            scrobbleService.currentTrack?.title ?? "",
            scrobbleService.currentTrack?.artist ?? "",
            dashboardHeroImageURL ?? "",
            (scrobbleService.currentTrackDetails?.tags ?? []).joined(separator: "|"),
            (scrobbleService.currentArtistDetails?.tags ?? []).joined(separator: "|")
        ].joined(separator: "::")
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

    private func tagLinks(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Link(tag, destination: lastfmTagURL(tag))
                        .font(.custom("Avenir Next Medium", size: 13))
                }
            }
        }
    }

    private func similarArtistLink(_ similar: LastfmSimilarArtist, compact: Bool) -> some View {
        Button {
            openURL(lastfmArtistURL(name: similar.name, fallback: similar.url))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                dashboardArt(similar.imageURL, size: compact ? 64 : 72)
                Text(similar.name)
                    .font(.custom("Avenir Next Medium", size: compact ? 13 : 14))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: compact ? 84 : 90, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func lastfmTagURL(_ tag: String) -> URL {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = tag.addingPercentEncoding(withAllowedCharacters: allowed) ?? tag
        return URL(string: "https://www.last.fm/tag/\(encoded)")!
    }

    private func lastfmArtistURL(name: String, fallback: String?) -> URL {
        if let fallback, let url = URL(string: fallback) {
            return url
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
        return URL(string: "https://www.last.fm/music/\(encoded)")!
    }

    private var placeholderFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var dashboardCardBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.72))
    }

    private var calloutBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var sectionDividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }
}
