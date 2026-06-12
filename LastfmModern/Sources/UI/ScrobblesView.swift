import SwiftUI

struct ScrobblesView: View {
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
