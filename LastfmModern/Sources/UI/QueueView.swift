import SwiftUI

struct QueueView: View {
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
