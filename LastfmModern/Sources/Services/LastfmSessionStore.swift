import Foundation

protocol LastfmSessionStoring {
    func save(_ session: LastfmSession)
    func load() -> LastfmSession?
    func clear()
}

final class LastfmSessionStore: LastfmSessionStoring {
    private let fileManager: FileManager
    private let sessionFileURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("LastfmModern", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        self.sessionFileURL = dir.appendingPathComponent("session.json")
    }

    func save(_ session: LastfmSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        try? data.write(to: sessionFileURL, options: .atomic)
    }

    func load() -> LastfmSession? {
        guard let data = try? Data(contentsOf: sessionFileURL) else {
            return nil
        }
        return try? JSONDecoder().decode(LastfmSession.self, from: data)
    }

    func clear() {
        try? fileManager.removeItem(at: sessionFileURL)
    }
}
