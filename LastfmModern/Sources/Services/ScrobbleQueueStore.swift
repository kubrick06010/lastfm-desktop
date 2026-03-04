import Foundation

protocol ScrobbleQueueStoring {
    var queueFileURL: URL { get }
    func load() -> [Track]
    func save(_ tracks: [Track])
}

final class ScrobbleQueueStore: ScrobbleQueueStoring {
    let queueFileURL: URL

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LastfmModern", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        queueFileURL = dir.appendingPathComponent("scrobble-queue.json")
    }

    func load() -> [Track] {
        guard let data = try? Data(contentsOf: queueFileURL) else { return [] }
        return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
    }

    func save(_ tracks: [Track]) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: queueFileURL, options: .atomic)
    }
}
