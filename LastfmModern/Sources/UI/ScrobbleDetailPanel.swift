import SwiftUI

struct ScrobbleDetailPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    let item: LastfmRecentScrobble
    let kind: DeepLinkTarget.Kind
    let availableWidth: CGFloat

    var body: some View {
        let metrics = DetailPanelMetrics(width: availableWidth)

        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                HStack {
                    Text(panelTitle)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.headerFont))
                    Spacer()
                    Text(scrobbleService.inspectStatus)
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                }

                if kind == .track || kind == .album {
                    trackHeader(metrics: metrics)
                }

                // Mirror the legacy iOS navigation model here: related content must follow the
                // entity the user opened, not the artist context we happen to have loaded.
                if kind == .track, let track = scrobbleService.inspectedTrackDetails {
                    statGrid(
                        listeners: track.listeners,
                        plays: track.playcount,
                        library: track.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !track.tags.isEmpty {
                        tagLinks(title: "Popular tags", tags: Array(track.tags.prefix(7)))
                    }
                    if !scrobbleService.inspectedSimilarTracks.isEmpty {
                        Text("Similar Tracks")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarTracksGrid(scrobbleService.inspectedSimilarTracks, compact: metrics.isCompact)
                    }
                }

                if kind == .album, !scrobbleService.inspectedSimilarAlbums.isEmpty {
                    Text("Similar Albums")
                        .font(.custom("Avenir Next Medium", size: 17))
                    similarAlbumsGrid(scrobbleService.inspectedSimilarAlbums, compact: metrics.isCompact)
                }

                if let artist = scrobbleService.inspectedArtistDetails {
                    if kind == .track || kind == .album {
                        Divider()
                    }
                    Text(artist.name)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.artistTitleFont))
                        .lineLimit(metrics.isCompact ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    artistSection(artist, metrics: metrics)

                    statGrid(
                        listeners: artist.listeners,
                        plays: artist.playcount,
                        library: artist.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !artist.tags.isEmpty {
                        tagLinks(title: "Tags", tags: Array(artist.tags.prefix(10)))
                    }
                    // Match the classic iOS app's semantics: only artist detail
                    // renders similar artists. Track/album detail get their own
                    // "similar" blocks instead of inheriting artist similarity.
                    if kind == .artist, !artist.similarArtists.isEmpty {
                        Text("Similar Artists")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarArtistsGrid(artist.similarArtists, compact: metrics.isCompact)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)
        }
    }

    private var panelTitle: String {
        switch kind {
        case .track:
            return "Track Detail"
        case .artist:
            return "Artist Detail"
        case .album:
            return "Album Detail"
        }
    }

    // Apple’s current adaptive-layout guidance favors reflow over brute-force
    // shrinking: keep hierarchy intact, switch arrangement when width becomes
    // constrained, and only scale typography within safe bounds. This panel
    // follows that approach by collapsing from a side-by-side inspector into a
    // stacked detail layout before text becomes unreadably narrow.
    // References:
    // Apple. (n.d.). ViewThatFits. https://developer.apple.com/documentation/swiftui/viewthatfits
    // Apple. (n.d.). Human Interface Guidelines. https://developer.apple.com/design/human-interface-guidelines/
    private struct DetailPanelMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 620 }
        var isNarrowCompact: Bool { width < 500 }
        var artworkSize: CGFloat {
            if isNarrowCompact { return min(180, max(128, width - 56)) }
            if isCompact { return min(220, max(150, width - 48)) }
            return 180
        }
        var headerFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 20 : 24) }
        var titleFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 22 : 26) }
        var subtitleFont: CGFloat { isNarrowCompact ? 14 : (isCompact ? 16 : 20) }
        var albumFont: CGFloat { isNarrowCompact ? 13 : (isCompact ? 14 : 16) }
        var artistTitleFont: CGFloat { isNarrowCompact ? 22 : (isCompact ? 26 : 32) }
        var sectionSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
        var stackSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
    }

    @ViewBuilder
    private func trackHeader(metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    private func trackTextBlock(metrics: DetailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerPrimaryText)
                .font(.custom("Avenir Next Demi Bold", size: metrics.titleFont))
                .lineLimit(metrics.isNarrowCompact ? 5 : 4)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(headerSecondaryText)
                .font(.custom("Avenir Next Medium", size: metrics.subtitleFont))
                .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                .fixedSize(horizontal: false, vertical: true)
            if let tertiary = headerTertiaryText {
                Text(tertiary)
                    .font(.custom("Avenir Next Medium", size: metrics.albumFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerPrimaryText: String {
        switch kind {
        case .track:
            return item.track
        case .artist:
            return item.artist
        case .album:
            return item.album ?? item.track
        }
    }

    private var headerSecondaryText: String {
        switch kind {
        case .track:
            return "by \(item.artist)"
        case .artist:
            return "Artist overview"
        case .album:
            return "by \(item.artist)"
        }
    }

    private var headerTertiaryText: String? {
        switch kind {
        case .track:
            if let album = scrobbleService.inspectedTrackDetails?.album {
                return "from \(album)"
            }
            return nil
        case .artist:
            return nil
        case .album:
            return nil
        }
    }

    @ViewBuilder
    private func artistSection(_ artist: LastfmArtistDetails, metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL, size: metrics.artworkSize)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func statGrid(listeners: Int?, plays: Int?, library: Int?, compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 132), alignment: .leading)]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            stat("Listeners", listeners)
            stat("Plays", plays)
            stat("In your library", library)
        }
    }

    private func similarArtistsGrid(_ artists: [LastfmSimilarArtist], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 88), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 90), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(artists.prefix(compact ? 6 : 8)) { similar in
                similarArtistLink(similar)
            }
        }
    }

    private func similarTracksGrid(_ tracks: [LastfmSimilarTrack], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(tracks.prefix(compact ? 6 : 8)) { track in
                similarTrackLink(track)
            }
        }
    }

    private func similarAlbumsGrid(_ albums: [LastfmSimilarAlbum], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(albums.prefix(compact ? 6 : 8)) { album in
                similarAlbumLink(album)
            }
        }
    }

    @ViewBuilder
    private func artwork(size: CGFloat = 180) -> some View {
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
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
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

    private func similarArtistLink(_ similar: LastfmSimilarArtist) -> some View {
        Button {
            openURL(lastfmArtistURL(name: similar.name, fallback: similar.url))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                artistArt(similar.imageURL, size: 74)
                Text(similar.name)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 74, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func similarTrackLink(_ similar: LastfmSimilarTrack) -> some View {
        Button {
            openURL(lastfmTrackURL(name: similar.name, artist: similar.artist, fallback: similar.url))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                artworkThumbnail(similar.imageURL, size: 74)
                Text(similar.name)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 92, alignment: .leading)
                Text(similar.artist)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 92, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    private func similarAlbumLink(_ similar: LastfmSimilarAlbum) -> some View {
        Button {
            openURL(lastfmAlbumURL(name: similar.name, artist: similar.artist, fallback: similar.url))
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                artworkThumbnail(similar.imageURL, size: 74)
                Text(similar.name)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 92, alignment: .leading)
                Text(similar.artist)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(width: 92, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func artworkThumbnail(_ urlString: String?, size: CGFloat) -> some View {
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

    private func lastfmTrackURL(name: String, artist: String, fallback: String?) -> URL {
        if let fallback, let url = URL(string: fallback) {
            return url
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: allowed) ?? artist
        let encodedTrack = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
        return URL(string: "https://www.last.fm/music/\(encodedArtist)/_/\(encodedTrack)")!
    }

    private func lastfmAlbumURL(name: String, artist: String, fallback: String?) -> URL {
        if let fallback, let url = URL(string: fallback) {
            return url
        }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encodedArtist = artist.addingPercentEncoding(withAllowedCharacters: allowed) ?? artist
        let encodedAlbum = name.addingPercentEncoding(withAllowedCharacters: allowed) ?? name
        return URL(string: "https://www.last.fm/music/\(encodedArtist)/\(encodedAlbum)")!
    }
}
