import Foundation

struct Track: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let startedAt: Date
    let sourceApp: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        startedAt: Date,
        sourceApp: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.startedAt = startedAt
        self.sourceApp = sourceApp
    }

    var fingerprint: String {
        "\(artist.lowercased())|\(title.lowercased())|\(Int(startedAt.timeIntervalSince1970))"
    }

    static let preview = Track(
        title: "Instant Crush",
        artist: "Daft Punk",
        album: "Random Access Memories",
        duration: 337,
        startedAt: .now,
        sourceApp: "Preview"
    )
}
