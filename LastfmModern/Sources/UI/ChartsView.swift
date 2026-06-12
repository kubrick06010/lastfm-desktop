import SwiftUI

struct ChartsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let onOpenTrack: (_ track: String, _ artist: String) -> Void
    let onOpenArtist: (_ artist: String) -> Void
    let onOpenAlbum: (_ album: String, _ artist: String, _ imageURL: String?) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = ChartsMetrics(width: proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Charts")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.screenTitleFont))

                    if !scrobbleService.weeklyTopArtists.isEmpty {
                        Text("\(scrobbleService.weeklyTopArtists.count) Artists")
                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))

                        LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                            ForEach(scrobbleService.weeklyTopArtists.prefix(8)) { artist in
                                VStack(alignment: .leading, spacing: 6) {
                                    cover(
                                        artist.imageURL,
                                        size: metrics.coverSize,
                                        placeholder: artist.name
                                    )
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\((artist.playcount ?? 0).formatted()) scrobbles")
                                        .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenArtist(artist.name)
                                }
                            }
                        }
                        .appPanelStyle()
                    }

                    Text("\(topAlbums.count) Albums")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                        ForEach(topAlbums.prefix(8), id: \.id) { album in
                            VStack(alignment: .leading, spacing: 6) {
                                cover(album.imageURL, size: metrics.coverSize)
                                Text(album.title)
                                    .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(album.artist)
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("\(album.count.formatted()) scrobbles")
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont - 1))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenAlbum(album.title, album.artist, album.imageURL)
                            }
                        }
                    }
                    .appPanelStyle()

                    Text("\(topTracks.count) Tracks")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    VStack(spacing: 10) {
                        ForEach(topTracks.prefix(10), id: \.id) { track in
                            HStack(alignment: .top, spacing: 10) {
                                cover(track.imageURL, size: metrics.trackCoverSize)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.custom("Avenir Next Medium", size: metrics.trackTitleFont))
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                    Text(track.artist)
                                        .font(.custom("Avenir Next Regular", size: metrics.trackMetaFont))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                }
                                Spacer(minLength: 8)
                                Text("\(track.count.formatted())")
                                    .font(.custom("Avenir Next Medium", size: metrics.trackCountFont))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenTrack(track.title, track.artist)
                            }
                        }
                    }
                    .appPanelStyle()
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // Charts use adaptive card columns instead of hard-coded horizontal strips.
    // The current desktop pattern is to let cards wrap as width changes and keep
    // content readable, rather than preserving a fixed card width that forces
    // clipping or excessive horizontal scrolling.
    private struct ChartsMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 980 }
        var isNarrow: Bool { width < 760 }
        var contentMaxWidth: CGFloat { isCompact ? .infinity : 1240 }
        var screenTitleFont: CGFloat { isNarrow ? 22 : 24 }
        var sectionCountFont: CGFloat { isNarrow ? 24 : 30 }
        var coverSize: CGFloat { isNarrow ? 136 : 156 }
        var trackCoverSize: CGFloat { isNarrow ? 46 : 54 }
        var cardTitleFont: CGFloat { isNarrow ? 15 : 16 }
        var cardMetaFont: CGFloat { isNarrow ? 13 : 14 }
        var trackTitleFont: CGFloat { isNarrow ? 16 : 18 }
        var trackMetaFont: CGFloat { isNarrow ? 14 : 16 }
        var trackCountFont: CGFloat { isNarrow ? 14 : 16 }
        var cardColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 144 : 160), spacing: 16, alignment: .topLeading)]
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
